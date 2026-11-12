# Haskell 98 front end

This library is the front end and the intermediate language of rhc, the
Haskell 98 compiler of the haskell98 roadmap. Rune alone builds it (the
roadmap's D42): the other SML systems may compile it, and nothing holds
them to it.

[`Core`](str/Core.md) is rhc's typed lazy intermediate language (D2): System F with type
constructors applied to types, a lazy `let` and `letrec`, and a `case` that
is the only thing that forces. A binding of type `T` may hold a suspension
and one of `!T` an evaluated value, so a strictness result has a type to go
to. Its text, [`CoreText`](str/CoreText.md), is a contract between the front end, which writes
it, and Core to Mid, which reads it: a program in it runs before there is a
parser. [`CoreLint`](str/CoreLint.md) checks a program, [`CoreInterp`](str/CoreInterp.md) runs it, [`CorePrim`](str/CorePrim.md) is
what it can do that is not Core, and [`CoreGen`](str/CoreGen.md) makes programs to test them
with. [`CoreToMid`](str/CoreToMid.md) lowers a program to Mid's text, a lazy position a
suspension and an evaluated one its value, which rhc gives to the passes of
`lib/compiler` from Mid on. A program may be in units (M21): a unit takes a
value of another by an import, `(import x TYPE)`, and a type by a copy of
its declaration, and [`CoreUnits`](str/CoreUnits.md) joins units into one program, which the
interpreter runs.

[`CoreRuntime`](str/CoreRuntime.md) is rhc's runtime, written in Core over [`CorePrim`](str/CorePrim.md) (M17, D26's
A: no SML below Haskell), so that the interpreter and the VM run one text:
the unit and the list, which are the Report's built-in syntax, and the
modules the Report imports and never defines, PreludeBuiltin and
UnicodePrims, each `prim*` of `share/rhc/haskell98` a value of it of the
same name. An action passes the state token (D25), and `getContents` and
`readFile` read through `interleave`, the one interleaving primitive; a
string literal is unpacked as its list is read (D24); a `Char` is a code
point, classed and mapped by `lib/unicode`'s tables (D21); a `Float` is
rounded to binary32 after each operation (D23). rhc links into a program
what it reaches of the runtime. A family of primitives ([`CorePrimFamily`](str/CorePrimFamily.md)) is
a file of its own, each primitive with what the interpreter does and the Mid
function it is lowered to: `CorePrimIo` gives the IO library's positions of
files and errors of the system's, over `CoreFiles`, the interpreter's files;
`CorePrimSys` the operating system's file system, process, environment,
clock, time zone and randomness, which Directory, System, Time, CPUTime and
Random read (the roadmap's M18), each over a primitive of Mid's.

The syntax (`syntax.build`, the roadmap's M11) reads a file of Haskell 98 to
a tree that keeps all of it. [`HsLiterate`](str/HsLiterate.md) gives a literate file's program
text, the length of the file; [`HsLexer`](str/HsLexer.md) makes it tokens, each with the
comments, pragmas and white space before it; [`HsLayout`](str/HsLayout.md) is the Report's
layout algorithm, run a token at a time as [`HsParser`](str/HsParser.md) pulls it, so that a
block the parser cannot go on with is closed there (`parse-error(t)`, D27).
[`HsAst`](str/HsAst.md) keeps operators in flat sequences until fixity is known, a span on
every node and every node's own tokens; [`HsPrint`](str/HsPrint.md) prints a tree with every
block in braces, by layout, or exactly as its file was (D28), and [`HsDump`](str/HsDump.md)
as text. [`HsSource`](str/HsSource.md) holds spans and the front end's errors, [`HsChar`](str/HsChar.md) the
Report's classes of characters.

Desugaring (`desugar.build`, the roadmap's M15) makes a checked program
the Core it means: [`HsDesugar`](str/HsDesugar.md) applies the Report's translations of
chapters 3 and 4 literally (D34's A), each class a data type of
dictionaries and each overloaded use its type and dictionary arguments as
the checker's evidence records give them (D31). [`HsMatch`](str/HsMatch.md) matches patterns
in the Report's order, or as decision trees in Sestoft's order for D34's
measurement; [`HsDsEnv`](str/HsDsEnv.md) is what desugaring knows of the program, its names,
types and records in Core, and [`HsDsCore`](str/HsDsCore.md) builds Core with its types.

The roadmap is `docs/plans/language/haskell98.md`.

[How to read these pages](../../conventions.md) &middot; [the structures](structures.md) &middot; [exceptions](exceptions.md) &middot; [what depends on what](depends.md) &middot; [what is documented](coverage.md) &middot; index: [a](index/a.md) [b](index/b.md) [c](index/c.md) [d](index/d.md) [e](index/e.md) [f](index/f.md) [g](index/g.md) [h](index/h.md) [i](index/i.md) [j](index/j.md) [k](index/k.md) [l](index/l.md) [m](index/m.md) [n](index/n.md) [o](index/o.md) [p](index/p.md) [q](index/q.md) [r](index/r.md) [s](index/s.md) [t](index/t.md) [u](index/u.md) [v](index/v.md) [w](index/w.md) [z](index/z.md)

## Languages

| Signature |  |
| --- | --- |
| [`CORE`](sig/CORE.md) | Core, rhc's typed lazy intermediate language (the haskell98 roadmap, D2): System F with type constructors applied to types (`m a`), a lazy `let` and `letrec`, and a `case` that is the only thing that forces. A value is passed by an atom, a variable or a literal, so every allocation is a `let` and every evaluation a `case`. |
| [`CORE_GEN`](sig/CORE_GEN.md) | A generator of Core programs (the haskell98 roadmap, D55, its second generator): well-typed lazy programs in Pałka's shape, a function from a list of `Int` to another, made of `map`, `take`, `let`, `letrec`, `case` and forcing, applied to a partial list, one with a bottom for an element or its tail, and its result printed to twenty elements. |
| [`CORE_INTERP`](sig/CORE_INTERP.md) | The Core interpreter (the haskell98 roadmap, M8): Launchbury's natural semantics of laziness as the specification, and Sestoft's machine as the program, slow by design. A `let` puts a suspension in the heap; a variable forced is evaluated once, under a marker that blackholes it, and updated with its value; a `case` waits on the stack for its scrutinee. Types are erased. |
| [`CORE_LINT`](sig/CORE_LINT.md) | CoreLint (the haskell98 roadmap, D2, D54): the check of a Core program. Core is explicitly typed, so the check is syntax-directed and unifies nothing: it works out the type of every expression from its parts and holds each to what its place wants. rhc runs it on Core read as text, at each boundary, and last before the crossing into Mid, where `Any` leaves MidLint weaker; a forgotten force, a lazy atom where `!T` is wanted, is the breach it is for above all. |
| [`CORE_PRIM`](sig/CORE_PRIM.md) | The primitives of Core (the haskell98 roadmap, D26): what Core can do that is not a function of Core, each with its type. An argument a primitive reads is evaluated, `!T`; one it may leave suspended, a function or a value it stores, is lazy. A primitive that does I/O takes the state token and gives it back, so that its order is its data's. |
| [`CORE_PRIM_FAMILY`](sig/CORE_PRIM_FAMILY.md) | A family of Core's primitives, defined in a file of its own (the haskell98 roadmap, M17, M18): each primitive with its type, what the Core interpreter does for it, and the Mid function Core to Mid lowers it to, defined in the family's Mid text. CorePrim lists each family's primitives after its own, CoreInterp runs them and CoreToMid lowers them, so that a family is added with no edit of any of the three but a line of CorePrim's. |
| [`CORE_RUNTIME`](sig/CORE_RUNTIME.md) | rhc's runtime, in Core (the haskell98 roadmap, M17; D24 to D26): what the Report's modules name and never define, written in Core over CorePrim's primitives, so that the Core interpreter and Core to Mid run one text and no SML stands below Haskell (D26's A). |
| [`CORE_TEXT`](sig/CORE_TEXT.md) | Core as text, and back (the haskell98 roadmap, D2): the contract between the front end, which writes Core, and Core to Mid, which reads it. `show` prints a program for a dump (rhc --dump-after) or a test (tests/hs/core), and `parse` reads what it prints, so that print, read, print is the identity; rhc checks that at lint level 3. |
| [`CORE_TO_MID`](sig/CORE_TO_MID.md) | Core to Mid (the haskell98 roadmap, M10): a Core program as a program of Mid's text, which rhc reads with Mid's own reader and gives to the passes from Mid on (MidPipeline), its list without expand. |
| [`HS_AST`](sig/HS_AST.md) | The abstract syntax of Haskell 98, the Report's chapter 10, before names and fixity are resolved (the haskell98 roadmap's D28). |
| [`HS_CHAR`](sig/HS_CHAR.md) | The classes of characters of the Haskell 98 Report's lexical syntax (chapter 2, section 9.2), by code point. |
| [`HS_CLASSES`](sig/HS_CLASSES.md) | The classes and instances of Haskell 98's checker (the haskell98 roadmap's M13; the Report's 4.3): every class and instance of the program, for entailment. Instances are not names: every instance a program declares, or derives, is in force in all of it. |
| [`HS_DERIVE`](sig/HS_DERIVE.md) | Haskell 98's derived instances (the Report's chapter 10; the haskell98 roadmap's M14, D33's C): the methods of a derived `Eq`, `Ord`, `Enum`, `Bounded`, `Ix`, `Show` or `Read` instance, made as the renamed tree a user would write, with chapter 10's text as the specification, so that the checker elaborates them as it does a user's instance and HsLint checks them as any instance (D54). |
| [`HS_DESUGAR`](sig/HS_DESUGAR.md) | Desugaring to Core (the haskell98 roadmap's M15, D34): a checked program made the Core program it means. |
| [`HS_DS_CORE`](sig/HS_DS_CORE.md) | Core as desugaring builds it (the haskell98 roadmap's M15): each expression with its type. |
| [`HS_DS_ENV`](sig/HS_DS_ENV.md) | What desugaring knows of a checked program (the haskell98 roadmap's M15): its names, types, records and dictionaries in Core. |
| [`HS_DUMP`](sig/HS_DUMP.md) | The abstract syntax of Haskell 98 as text, for `rhc --dump-ast` and for the tree round trip of a test that compares trees by their text. |
| [`HS_EVIDENCE`](sig/HS_EVIDENCE.md) | The evidence records of Haskell 98's checker (the haskell98 roadmap's D31, M13): what inference chose at each node of the renamed tree, by node, in the manner of Rune's `Witness` (lib/compiler/elab/witness.sml), for desugaring to Core (M15) to translate and HsLint (M16, D54) to check: each overloaded use's dictionaries, each binder's type and the dictionary parameters it is abstracted over, each instance's dictionaries, and each defaulting, with what it chose from. |
| [`HS_FIXITY`](sig/HS_FIXITY.md) | Haskell 98's fixity resolution (the Report's 10.6, 3.4, 3.5 and 4.4.2; the haskell98 roadmap's M12): the flat sequences of operators the parser leaves, [`HsAst.ESeq`](sig/HS_AST.md#con-eseq) and [`HsAst.PSeq`](sig/HS_AST.md#con-pseq), made into trees by the fixities of the operators' entities, read after names (D29), so that a renamed tree is resolved with no iteration. |
| [`HS_IFACE`](sig/HS_IFACE.md) | HsIface, rhc's interface of a unit (the haskell98 roadmap's M21, D44): what a store keeps of a unit for a client, written and read back. Each of its modules' interfaces as the renamer and the checker make them (HsModIface), and the desugaring's part, its Core among it, as text the desugaring gives. The unfoldings section is in the format from the start and empty until M23 (D44's C). |
| [`HS_INFER`](sig/HS_INFER.md) | Haskell 98's type checker (the haskell98 roadmap's M13, D30, D31, D32, D33): one inference over the renamed, fixity-resolved trees of a unit, the modules of one strongly connected group, joined, so that a binding group or a type group may cross its modules, with what it chose recorded by node in HsEvidence's table. |
| [`HS_KINDS`](sig/HS_KINDS.md) | The type constructors of Haskell 98's checker and their kinds (the haskell98 roadmap's M13; the Report's 4.6): kind inference over a unit's `data`, `newtype`, `type` and `class` declarations by dependency group, a kind left open defaulting to `*`, so that a type group may cross the modules of a cycle (R28, D30); the kind checking of every other type a program writes; and the types of the tree made the checker's, synonyms expanded. |
| [`HS_LAYOUT`](sig/HS_LAYOUT.md) | The layout algorithm of Haskell 98, the function `L` of the Report's section 9.3, run on demand: the parser pulls one token at a time, so that when it takes an implicit close, the side condition `parse-error(t)` of the equation for `t`, the stack of layout contexts is that of the point it has reached and nothing past that token has been laid out (the haskell98 roadmap's D27). |
| [`HS_LEXER`](sig/HS_LEXER.md) | The lexer of Haskell 98: the Report's chapter 2 and section 9.2, over program text. |
| [`HS_LINT`](sig/HS_LINT.md) | HsLint (the haskell98 roadmap's M16, D54): the independent check of rhc's types, as AstLint is Rune's. Its first part is a second inference: a transliteration of Typing Haskell in Haskell (Jones 1999) in the form its 11.6.3 calls conformant, with kinds and dependency groups recomputed, the monomorphism restriction and defaulting as the roadmap's D32 reads the Report (R18, R20, R21, R22), over the renamed tree. It shares nothing with rhc's checker but the renamer: its unifier, its kinds and its context reduction are its own, so that a disagreement between the two is a finding. rhc runs it among the checks of level 2 (`--lint=2`, `RUNE_LINT=2`), where a refusal of a program the compile accepts is a bug of rhc's. |
| [`HS_LITERATE`](sig/HS_LITERATE.md) | Literate Haskell (the Report's section 9.4): the program text of a literate file. |
| [`HS_MATCH`](sig/HS_MATCH.md) | Pattern matching in the Report's order (the haskell98 roadmap's M15, D34), and decision trees in Sestoft's order as an option. |
| [`HS_MODULES`](sig/HS_MODULES.md) | The names of Haskell 98's modules (the Report's chapter 5; the haskell98 roadmap's D29, D30): what each module defines, what it exports, and what is in scope in it, over a group of modules that import one another. |
| [`HS_MOD_IFACE`](sig/HS_MOD_IFACE.md) | A module's interface as the renamer and the checker make it (the haskell98 roadmap's M21, D44): what a client of the module needs of it to be named and checked against it in place of its source, by entity, and the fingerprints a store's usages compare (E13's H5, H6). HsIface, rhc's interface of a unit, holds one for each of its modules beside its Core, and codes them. |
| [`HS_PARSER`](sig/HS_PARSER.md) | The parser of Haskell 98: recursive descent over the grammar of the Report's section 9.5, on the layout of [`HsLayout`](str/HsLayout.md) (the haskell98 roadmap's D27). |
| [`HS_PRINT`](sig/HS_PRINT.md) | Printers of Haskell 98's abstract syntax (the haskell98 roadmap's D28). |
| [`HS_RENAME`](sig/HS_RENAME.md) | Haskell 98's renamer (the haskell98 roadmap's M12): every name of a module's tree resolved to what it stands for, in the scope that [`HsModules`](str/HsModules.md) gives the module and the scopes its own bindings make. |
| [`HS_SCC`](sig/HS_SCC.md) | Strongly connected components, for the dependency analyses of Haskell 98's checker: of type declarations for kinds (4.6), and of bindings for declaration groups (4.5.1). |
| [`HS_SOURCE`](sig/HS_SOURCE.md) | Haskell source text: spans, positions and the errors of the front end. |
| [`HS_STRING_MAP`](sig/HS_STRING_MAP.md) | Maps keyed by strings, as the front end's scopes, exports and tables need them: persistent, ordered by the keys, and balanced (red-black trees, inserting only), so that a fold visits the keys in order and a result does not depend on the order things were added. |
| [`HS_TOKEN`](sig/HS_TOKEN.md) | The lexemes of Haskell 98 (the Report's chapter 2 and section 9.2), with what lies between them. |
| [`HS_TYPES`](sig/HS_TYPES.md) | The types of Haskell 98's checker (the haskell98 roadmap's M13, D31): kinds, types with unification variables, predicates and schemes, and first-order unification with levels. |
| [`HS_USAGE`](sig/HS_USAGE.md) | What a compile of a unit reads of the units it imports (the haskell98 roadmap's M21, E13's obligations H1, H2, H7 and H9), noted where the renamer, the checker and the translations read it, so that a store's entry of the unit is used only where each read gives now what it gave then. A read is noted found or not: a name a module looks up and does not find is read too, since an import that comes to export it changes the module (5.5.2). The note is a no-op until a driver sets it (rhc's, src/rhc/iface.sml). |

## Not yet assigned to an area

| Signature |  |
| --- | --- |
| [`CORE_UNITS`](sig/CORE_UNITS.md) | Core in units (the haskell98 roadmap's M21): a program of several units, each a Core program that names what it takes of the others, a value by an import (`(import x TYPE)`) and a type by a copy of its declaration, joined into one program, which Core's interpreter runs and a compile whole takes. |

---

<sub>Generated by runedoc; do not edit.</sub>

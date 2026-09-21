# Architecture

```
source files ──► Lexer ──► Parser ──► Elaborate ──► Translate ──► Codegen ──► Emit ──► .rbc
                 tokens     AST        typed AST    Lambda IR     bytecode
                                                                   items
.rbc ──► loader (validate) ──► interp (stack machine, prims, Cheney GC)
```

The compiler is a classic multi-pass design in `src/`; the VM is in `vm/`.
Every pass is a separate structure with a small interface so the pipeline can
be inspected with `rune --dump-tokens | --dump-ast | --dump-lambda | --dump-code`.

## Compiler passes

| Pass | Files | Input → output | Notes |
|---|---|---|---|
| Lexer | `src/frontend/token.sml`, `lexer.sml` | text → token vector | Hand-written. Recognises long identifiers, `~` in numeric literals, `#"c"`, string gaps, nested comments and the `_prim` extension. Produces a vector so the parser can backtrack. |
| Parser | `src/frontend/ast.sml`, `fixity.sml`, `parser.sml` | tokens → `Ast.program` | Recursive descent. Infix expressions/patterns are collected as flat item lists and resolved by precedence climbing against the current fixity environment (`infix` directives are lexically scoped and threaded across files). `fun` clause heads try the `(p op q) r` form first, then the generic form. |
| Elaboration | `src/elab/types.sml`, `overload.sml`, `unify.sml`, `env.sml`, `sigmatch.sml`, `elaborate.sml` | AST → AST with annotations | Hindley–Milner with levels for let-polymorphism, kinds on type variables for overloading (`KOverload`: the admissible kinds `int word real char string`; `Overload` maps a type constructor, by stamp, to its kind, to the primitive or top-level variable behind each operator and to the form of its constants; the basis library adds types to it with `_overload`, and int and word constants are typed with an overloaded variable of their kind, whose resolved type `Translate` finds in the constant's slot) and flexible records (`KFlex`), value restriction via non-expansiveness. Fills the mutable annotation slots in the AST (`varinfo`, `patinfo`, record types for `#lab` and `{...}`) instead of building a separate typed tree. Every binder gets a globally unique integer stamp. Overloaded operators and flexible records are resolved/defaulted at the end of each top-level declaration. Types are built from type names (`Types.tycon`: stamp, arity, equality attribute) and type functions; `Env.TyStr` is the Definition's type structure. `SigMatch` implements signatures (flexible names + environment), `where type`/`sharing` as realisations, matching by enrichment and ascription. |
| Match compilation | `src/core/lambda.sml`, `matchcomp.sml` | patterns → `Lambda` tests | Rules are tried in order; each test that fails executes `Fail`, which jumps to the enclosing `Try`'s fallback (the next rule). Irrefutable patterns emit no tests. Constructor tests compare `ConTag`; exception patterns compare constructor identity. |
| Translation | `src/core/translate.sml` | annotated AST → `Lambda.lexp` | Records become tuples in canonical label order (evaluated in source order), `while` becomes a tail-recursive local function, overloaded operators resolve to typed primitives, constructors/exceptions applied directly avoid closures, so do applications of a variable bound to a primitive (`val op + = _prim "int_add" : ...` in the basis library, and `val size = String.size` after it), top-level bindings become globals (`SetGlobal`/`Global`), everything else is lexically scoped `Let`/`LetRec`. |
| Code generation | `src/backend/codegen.sml` | Lambda → per-function instruction lists | Flat closure conversion: free variables are computed per `Fn`, loaded in the enclosing function and stored in the closure environment. Self reference uses `SELF`; mutual recursion patches environment slots with `SETENV`. Locals get frame slots; tail calls are detected syntactically. |
| Emission | `src/backend/emit.sml` | program → bytes | Resolves labels to absolute offsets, writes the `.rbc` layout documented in `docs/bytecode.md` as string chunks through `BinIO`. |
| Driver | `src/driver/basismanifest.sml`, `options.sml`, `main.sml` | CLI | `BasisManifest` reads `lib/basis/MANIFEST` and chooses the files a program loads (the documentation generator uses it too). The driver tokenizes the user files, picks the files of the basis library they need from `lib/basis/MANIFEST` (the always-loaded files, the files that provide a name among the identifiers of the program, and the closure of their requires column; `--basis all` takes every file), and compiles those and the user files as one program. `--basis-deps` prints the choice; `--basis-check` verifies the MANIFEST against the sources. |

Shared utilities: `src/util/ordmap.sml` (AVL maps: `functor OrdMapFn`,
applied as `StringMap`/`IntMap`), `source.sml` (files, spans, line/column),
`error.sml` (`CompileError`, `Bug`).


## The documentation generator

`runedoc` ([docs/plans/docgen.md](plans/docgen.md)) is a second program built
from the same sources: `sources-doc.txt` lists the utilities, the frontend and
the elaborator of the compiler, `BasisManifest`, and `src/doc`. It reads a
library the way the compiler does (the same lexer, parser and, later,
elaborator), so what it documents is what the compiler compiles. Nothing of
`src/doc` is part of the compiler, so it costs the bootstrap nothing.

| Structure | File | Purpose |
|---|---|---|
| `DocSource` | `src/doc/docsource.sml` | A file's tokens, the comments in the gaps between them (the lexer keeps none; every gap is white space and comments, or it is a bug), and source text without comments. |
| `DocDiag` | `src/doc/docdiag.sml` | Diagnostics that accumulate: a run reports everything, in source order, and fails at the end if there was an error. |
| `DocComments` | `src/doc/doccomments.sml` | What each comment documents, by line: the item directly below it, or the innermost item that ends on its line; a comment that starts with `----` is a section heading, one followed by a blank line is prose. In a signature a comment that is none of these is an error. |
| `DocText` | `src/doc/doctext.sml` | The language of doc comments ([doc-comments.md](doc-comments.md)): paragraphs, code between backquotes, code blocks, lists, links and the reserved paragraphs (`Raises:`, `Implements:`, the notes), with what each of those must look like. |
| `DocHead` | `src/doc/dochead.sml` | Usage heads: `` `take (l, i)` `` at the start of a value's description is parsed with the compiler's parser and checked against the type of the specification; its arguments name the arguments for the rest of the comment. |
| `DocIR` | `src/doc/docir.sml` | The intermediate representation: modules, the entries of a signature in source order, constructors, fields. Renderers read only this. `dump` is its text form. |
| `DocExtract` | `src/doc/docextract.sml` | Syntax tree and comments to `DocIR`, in two walks: the first notes what can be documented, the second builds the modules with their comments. Specifications are shown as the source has them; the parser's derived forms (`type t = ty`, `include A B`) are recognised and undone. |
| `DocAnchor` | `src/doc/docanchor.sml` | The explicit anchors of a page, `kind-name` in lower case with symbolic identifiers spelled out (`val-op-at`): GitHub's own anchors are useless for SML. |
| `DocMarkdown` | `src/doc/docmarkdown.sml` | Markdown as GitHub reads it: what must be escaped for text to stay text, blocks, tables. |
| `DocClaims` | `src/doc/docclaims.sml` | What implements what: the `Implements:` paragraphs of structures and functors, the ascriptions of the source, and the substructures a structure has through `structure A = B`. They give the signature pages their implementations and are written to `claims.tsv`, which `tests/basis/check-claims.sh` compares with what the suite matches against the specification's signatures. |
| `DocElab` | `src/doc/docelab.sml` | The library through the compiler's elaborator, file by file as the driver does it. A claim is checked by elaborating `structure Claim : SIG where type ... = S` on top, and the compiler's complaint is the diagnostic; a usage head is checked against the elaborated type of its value, with abbreviations expanded. It also answers what only elaboration knows: whether an example that is an equation is well typed (`checkExample`), what a structure without a body in the source declares and what a signature specifies with its includes (`namesOf`, `specifiedBy`, for the names beyond the signature of `structures.md`), which types have one type name (`typeNames`, for `types.md`), and whether a signature with its `where type`s says which type one of its types is or leaves it abstract (`typeSpecOf`, for the reason that `types.md` gives with every name). A library other than the Basis Library is elaborated on top of it. |
| `DocTests` | `src/doc/doctests.sml` | The checks of a test suite, read out of its sources with the compiler's parser: the labels `Structure.member/case` (literal, or literal and computed), what kind of check each is and which exception a `raises` expects, test functors expanded by the `name` each application gives. The pages list the checks of every member, and generation fails for a specified member of a claimed structure that has none. |
| `DocNotes` | `src/doc/docnotes.sml` | The notes of the doc comments (readings, errata, deviations, implementation choices, limitations) with what pins them: the `Pinned by:` globs, which must match checks of the suite, or the check whose label is the note's id. They are written to `notes.tsv` and `readings.md`; `tests/basis/check-notes.sh` compares the export with `deviations.txt`, so that the suite depends on the documentation and not the other way round. |
| `DocAnnot` | `src/doc/docannot.sml` | Annotations: what a file made elsewhere says about the members, `glob \| whom it is about \| text`, where the glob is that of a check's label (`*`, `?`, `[...]`). An annotation is shown under every member with such a check, and one that finds none is an error. The Basis Library's file is `tests/basis/annotations.txt`, the host lines of `deviations.txt` as `tests/basis/gen-annotations.sh` writes them. |
| `DocExamples` | `src/doc/docexamples.sml` | The pieces of `Example:` paragraphs that are equations, `e = v`: which structure they are read in (`open Int` for `INTEGER`), the expression that `DocElab` elaborates when the documentation is made, and the program for each signature that `runedoc --examples` writes and `tests/basis/run-examples.sh` runs. |
| `DocResolve` | `src/doc/docresolve.sml` | What a code span that is an identifier refers to: an argument of the usage head, a member of the signature (through its substructures and includes), a module; `List.map` leads to the page of `LIST`. |
| `DocPage` | `src/doc/docpage.sml` | The page of a signature: status, synopsis, overview, contents, the interface with its identifiers linked, the entries with their tables of constructors and fields, notes as quotations. |
| `DocSite` | `src/doc/docsite.sml` | A library's documentation as a tree of files: the pages, the overview by area, the index of identifiers, `conventions.md`, `coverage.md`, `structures.md` (with the names a structure declares beyond its signature), the pages of the functors, `top-level.md` (what the files that every program loads declare, each name with the structure member it is and that member's description), `exceptions.md` (from the `Raises:` paragraphs), `readings.md`, `claims.tsv`, `notes.tsv`; the ratchet of `DOCUMENTED`; checks that every anchor is unique and every link leads somewhere, that no page is too large for GitHub; writes the tree or compares it with the one on disk. |
| `DocMain` | `src/doc/docmain.sml` | The command line: `runedoc --library NAME --out DIR [--check]`, and `--page`, `--dump-ir`, `--lint` on files. |

Its tests are `tests/doc` (`make test-doc`): an input file and, next to it,
what `runedoc` is expected to make of it (`.ir`, and `.md` for the page) and
to complain about (`.diag`).

## Modules

Signatures and functors exist only at compile time. A signature elaborates
to a set of flexible type names plus an environment; `where type` and
`sharing` are realisations of those names, and ascription matches the
structure against the signature (instantiation, then enrichment) and returns
the signature's environment with the structure's stamps and constructor
tags. Opaque ascription renames the flexible names to fresh ones. A functor
body is type-checked once against its parameter signature when declared;
every application copies the body's AST (`Ast.copyStrexp`, fresh annotation
slots), elaborates the copy with the parameter bound to the matched argument,
stores it in the `StrApp` node, and `Translate` emits it in place. Structures
therefore stay flattened to globals, datatype tags are those of the actual
argument, and datatypes and exceptions in a body are generative per
application.

## Bootstrapping

The compiler is compiled by itself, and the result is what Rune ships:
`make boot` compiles the sources with a host build (`BOOTHOST`, by default
MLton) into `bin/rune.rbc`, which `runevm` executes as `bin/rune-boot`, and
`bin/rune` names that. The host builds `bin/rune-mlton`, `bin/rune-smlnj` and
`bin/rune-polyml` exist to bootstrap it and to check it: `make bootstrap`
verifies that the self-hosted compiler reproduces `bin/rune.rbc` byte for
byte, and `check-cross` verifies that all four builds agree on every test
program. This works because every
pass is deterministic (ordered maps, counter-generated stamps, reals passed
through as text) and because the compiler sources use only what Rune itself
supports (`docs/building.md`, portability rule 6): explicit `IntInf`
operations and the `TextIO`/`BinIO` file streams of Rune's basis.

None of the four builds knows where the basis library is: `--lib DIR` is
required, and each `bin/rune*` is a wrapper script that supplies it and execs
the payload beside it. The bytecode therefore contains no path, and
`make install` only has to write a different wrapper.

## Virtual machine

| File | Contents |
|---|---|
| `vm/vm.h` | `Value`, `Obj`, `VM` and the shared API. |
| `vm/loader.c` | Reads and validates `.rbc` (see `docs/bytecode.md`), disassembler. |
| `vm/interp.c` | Stacks, frames, handlers, `vm_run` dispatch loop, structural equality, exception raising. |
| `vm/heap.c` | Allocation and the Cheney semispace collector. Roots: value stack, globals, constants, frame closures, builtin exception constructors. |
| `vm/prims.c` | One function per primitive; the dispatch table is generated from `prims.def`. |
| `vm/sys.h`, `vm/sys_posix.c`, `vm/sys_none.c` | The system layer: what the primitives of time, files, processes, `Posix` and sockets need from the operating system. `sys_posix.c` is the one for POSIX systems; `make SYS=none` links `sys_none.c` instead, which fails every call with `ENOSYS`, so the rest of the VM stays ISO C99. |
| `vm/main.c` | Command line handling. |

GC discipline in C: an allocation may move every heap object, so primitives
read their arguments from the stack (not popped) until the result exists, and
temporaries that must survive an allocation are pushed on the value stack
(`vm_cons` shows the pattern).

## Basis library

`lib/basis/*.sml` is ordinary SML compiled before a program that needs it; the
order, and what each file provides and requires, is in `lib/basis/MANIFEST`. A
file that is loaded on demand declares modules and types only, all listed in
its provides column, so that the top-level
environment of a program does not depend on which files it happens to load. Two
files are compiled before every program: `initial.sml` (`option`, `order` and
the exceptions that are not built in) and `pervasive.sml` (the values of the
top-level environment, written on primitives; `List.map` is the top-level
`map`, not the other way round, so that these 90 lines need no other file). The
driver loads a file on demand when the program names something it provides,
with the files it requires. The last files of the list are `seal` files: each
binds the structures of one file again, ascribed to their signatures
(`structure List : LIST = List`), and is loaded for a program that names one
of them, never for a file of the library. So the library is compiled with
every structure whole, its helpers included, and a program sees what the
specification names. A seal is opaque where it makes a type abstract that no
other signature names (`Date.date`, the ids of `Posix`), and keeps the types
that other signatures name by `where type`, because those signatures were
elaborated with the structure whole. A `final` file (`epilogue.sml`, which runs the
`OS.Process.atExit` actions) is compiled after the program, and only when
the files it requires are loaded already. Primitives are bound with
`_prim "name" : ty`. The tags of `option` and `order` are relied upon by
primitives that construct options.

## Adding a language feature (checklist)

1. Lexer/parser/AST as needed; elaboration (types + annotations); translation
   to Lambda; codegen only if a new Lambda construct is required.
2. If the VM needs a new instruction or primitive: `vm/opcodes.def` /
   `vm/prims.def`, implement in `vm/`, document in `docs/bytecode.md`.
3. Add `tests/lang/<id>_<name>.sml` + `.expected` (verify the expected output
   by hand, not just by running Rune) and the row `<id>` in `docs/language.md`.
4. `make check` must pass (all three compiler builds, identical bytecode,
   docs in sync).

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
| `DocIR` | `src/doc/docir.sml` | The intermediate representation: modules, the entries of a signature in source order, constructors, fields. Renderers read only this. `dump` is its text form. |
| `DocExtract` | `src/doc/docextract.sml` | Syntax tree to `DocIR`. Specifications are shown as the source has them; the parser's derived forms (`type t = ty`, `include A B`) are recognised and undone. |
| `DocMain` | `src/doc/docmain.sml` | The command line: `runedoc --dump-ir FILE...`. |

Its tests are `tests/doc` (`make test-doc`): an input file and, next to it,
what `runedoc` is expected to make of it.

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
with the files it requires. A `final` file (`epilogue.sml`, which runs the
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

# Roadmap: documentation generation (docgen)

This document turns the owner's specification for a documentation generator
(kept verbatim below) into a roadmap: what exists today, the decisions to
take, the language of the doc comments, what a generated page looks like, and
the milestones in order. The first library to document is the Basis Library,
into `docs/generated/basis`. [docgen-mock-LIST.md](docgen-mock-LIST.md) is a
hand-written mock of one generated page, and
[docgen-notes.tsv](docgen-notes.tsv) the inventory of readings and deviations
that the documentation has to absorb. Written 2026-09-20; every number below
was measured on commit `ea3d166` or is cited with its file and line.

## Status

| Milestone | State |
|---|---|
| M0, research, spikes, mock page, this roadmap | done, except the live rendering probe (needs a pushed branch) |
| Decisions D1 (where the doc comments live) and D4 (packaging) | taken by the owner on 2026-09-20: D1 = A (the library's signature files, by hand), D4 = a second executable `runedoc` |
| M1, the prerequisites in the compiler and the scripts | done: a comment byte costs the lexer 47 instructions (from 93); `include A B C` has the spans of its names; `--dump-tokens` only lexes; `gen-basis-sigs.sh` never writes an existing signature file and `--check` compares tokens |
| M2, the tool | done: `BasisManifest`; `runedoc` built by all five hosts, with `check-doc-cross`; `DocSource`, `DocIR`, `DocExtract`, `runedoc --dump-ir`, `tests/doc`, a perf budget |
| M3, comments and what they document | done: `DocComments`, `DocDiag`; only 2 of the corpus's group labels stood in a documented signature (`sig_text_io.sml`), and they are headings now |
| M4, the comment language | done: `DocText`, `DocHead`, `runedoc --lint` in `make check-docs` (8 s), [doc-comments.md](../doc-comments.md) for authors; the 935 comments of the corpus needed no change |
| M5, the renderer and the generated tree | done: `DocPage`, `DocResolve`, `DocAnchor`, `DocMarkdown`, `DocSite`; `make docs` writes [docs/generated/basis](../generated/basis/README.md) (95 files, 3.5 s on `runevm`), `runedoc --check` in `make check-docs`; nothing is documented yet, so coverage is 0 of 1,538 entries |
| M7, implementations (done before M6, so that the pilot's references to structures resolve) | done: 190 `Implements:` claims seeded into `lib/basis` from `tests/basis/*_sig.sml`, `Status: optional` on the optional structures, `DocClaims`, Synopsis tables, `structures.md` with the names beyond each signature, the three functor pages, notes of structure and functor bodies under the members, `claims.tsv`, `tests/basis/check-claims.sh` in `make check-docs`; `IntInf : INTEGER` is tested now, and `LargeInt` claims `INTEGER` only, as the specification has it |
| M6, the pilot wave | done: BOOL, CHAR, INT_INF, LIST, OPTION, OS_IO and STRING_CVT are documented in full (126 of 1,538 entries; 99 of 1,078 functions have a checked usage head) with 24 notes from [docgen-notes.tsv](docgen-notes.tsv), and are on the ratchet list `lib/basis/DOCUMENTED`. What the pilot changed in the tool: a comment may stand above the first constructor of a datatype (before its `=`), a usage head may name record fields as a pattern does, summaries are limited to 160 characters. **The grammar is ready for the owner's review**; the test and library comments that restate the pilot's notes are left for the waves to shorten. [docgen-mock-LIST.md](docgen-mock-LIST.md) is superseded by [the generated page](../generated/basis/sig/LIST.md) |
| M8, elaboration | done: `DocElab` elaborates the library as the driver does and checks all 197 claims by ascription (1.2 s natively, about 5 s on `runevm`; a false claim fails with the compiler's message), usage heads are checked against elaborated types, `top-level.md` is generated from the files every program loads and the `val null = null` twins of the structures (each name with the description of the member it is), signature entries say when they are also at the top level, `exceptions.md` lists who raises what, unqualified top-level names such as `Subscript` resolve to the member of `General` they are. Value twins are found by syntax, as planned; aliases are shown from the syntax too (`structures.md`), and the members of a structure that is an alias or a functor application are not listed yet |
| M9, the test inventory | done: `DocTests` reads the 31,694 check sites of `tests/basis` with the compiler's parser (test functors expanded by their `name`), every one of the 136,063 labels of a run matches a literal or a pattern of it, and the 535 literals that did not run are the conditional ones; the 20 sites that computed the member were rewritten to the convention (label beginnings as literals) without changing one printed label; every entry lists its checks in a collapsed block, a functor's check once with the structures it is applied to; generation fails for a specified member without a check (3,908 members of claimed structures), so `scripts/check-basis-coverage.sh` is gone. The label list is not committed (`runedoc --tests tests/basis --labels` prints it). Found on the way: `Word8` is sealed with `WORD` but no `_sig` test matches it, and eight of its members (`toLarge`, `fmt`, `scan`, ...) have no check under its name |
| M10, the notes | done: `DocNotes` collects the notes (26 so far, all of the pilot) with their pins, checks that an id names one note and that every `Pinned by:` glob matches a check of the suite, and writes `notes.tsv` and [readings.md](../generated/basis/readings.md); `coverage.md` lists the deviations and limitations that no check pins; `tests/basis/check-notes.sh` in `make check-docs` holds the export against `deviations.txt` (deleting the CHAR note, or the `rune` line, fails it). `runedoc` never reads `deviations.txt`. **The page layout is ready for the owner's review** |
| M11, the waves W1 to W8 | not started: 1,412 entries and about 410 notes of [docgen-notes.tsv](docgen-notes.tsv) to go; the last wave replaces the three sections of `docs/basis-compat.md` by links |
| M12, optional | not started |

## Specification from the Human
- Rune should have good library documenation that can be automatically generated from the source code.
- The first library we want to document properly is Basis. The generated documenation can go under docs/generated/basis.
  - The documentation should be at least as complete as https://smlfamily.github.io/Basis/ but ideally more so. I want Rune to have best-in-class documentation for its standard library.
  - Review the Basis library documentation from other SML compiler (at least SML/NJ, PolyML and MLton) and OCaml and Haskell for inspiration
  - Also review the standard library documentation and the documenation tools of other major programming languages for inspiration 
  - Also review the ambigutities we found during the implemenation of Basis (e.g. under tests/basis/deviations.txt). This should be part of the generated documentation. There is a tricky question of how to keep things in sync here again. docgen should almost certainly not depend on this ad hoc build artifact. Maybe inverse the dependecy somehow? Make a coherent plan.
- The documentation generation tool should re-use the compilers's parsing and other infrastructure.
  - In the future we also want to add the results of partiallity/exception checks and other compile-time analyses to the documentation. The compiler does not support this today and implementing this is beyond the scope of *this* roadmap. Just keep it in mind.
- As an end results I like something like this: https://hackage.haskell.org/package/containers-0.4.0.0/docs/Data-Map.html
  - A high-level overview of what the library/module does.
  - Entry for each language construct it exposes.
  - structs/functors etc.
  - for each data type it should have a table with constructors (constructor name, and description and then also each field in the constructure with its type and description)
  - for each function the name and its full type signature, then below that function heads a description of the function based on the comments in the source code.
- Source code comments (* ... *) should be a 'formal' language.
  - Really most plain natural language comments should we correct in this language. But there may be special constructs inside it that have restriction on their syntax. Docgen may warn or error if those are not adhered to.
  - For now we can just have the docgen check correctness of the comments and not have the compiler waste time on that. I kinda suspect that in the future we do want the compiler to also check the comments automatically as a good engineering practice.
  - Follow roughtly the Haskell/Haddock style for now:
    - Comments at the very top of an .sml file / signature are used to generate the introductory paragraphs in the generated documenation.
    - Comments directly above a function go into the generated documentation below the function header.
    - Comments following a contructor or field in a datatype are used to generate the datatype tables in the generated documenation.
  - It seems exisiting SML documentation tools (sigdoc, PolyDoc) are signature rather than .sml based. Probably good to follow that practise.
    - Please also review sigdoc, PolyDoc and any other SML doc generator (their source code and documentation) for further ideas.
- Also have docgen generate an overview page with module hierarchy and any refernce materials you think are useful.
  - Each signature document should also include a test inventory. Idealy auto-generate this to the greatest extent possible. We don't just want to store that as a comment in each .sml file as that can easily get out-of-date.
  - We probably also want some more cross-referencing in the documentation. E.g. for each signature we also want to list the implemenations available in the library (reversing the direction of what is available in the source code).
- I think Markdown is the best output format for now as Github can render it properly. Included the crosslinks between various markdown files.
  - Having some kind of intermediate representation that can be used the generate in various formats (Markdown, HTML, latex) is a future goal. The other output format are not a deliverable in the initial roadmap as we should build some proper libraries to do xml output etc. first (and that would go beyond the scope of this exercise). but keep it in mind.

## Where we are

### The compiler's frontend, as a doc tool sees it

* **Comments are thrown away, but nothing is lost.** `Lexer.skipComment`
  (`src/frontend/lexer.sml:28-33`, called at `:186`) returns only the index
  after `*)`. `Source.load` keeps every file's text in `Source.files`
  (`src/util/source.sml:54-59`), spans are byte offsets, and the token vector
  of `Lexer.tokenize` has strictly increasing spans (0 overlaps in 148,094
  tokens). A probe over all 264 source files of `lib/basis`, `src` and
  `tests/basis/spec-sigs` found that every gap between two tokens is
  whitespace plus complete comments, so comments can be recovered by
  rescanning the gaps without touching the lexer. A `(*` inside a string is
  inside a `STRING` token and cannot confuse the scan.
* **Spans.** Every `spec`, every description in a spec (`a : t` of
  `val a : t and b : u`, without `val`/`and`), every datatype constructor and
  every module binding has a span (`src/frontend/ast.sml:105-134`). A span
  ends at the item's last token, so a trailing comment on the same line lies
  outside it. Record fields have no label span (`TyRecord`, `ast.sml:74`);
  the label is recoverable from the tokens before the field's type, and a
  label span would touch 6 sites (`ast.sml:74,315`, `parser.sml:146-148`,
  `elaborate.sml:160,283,284`).
* **Derived forms are desugared in the parser, recoverably.** `type t = ty`
  in a signature becomes `SpecInclude (SigWhere (SigSig [SpecType ..], ..))`
  with all spans equal (`parser.sml:976-980`); a user-written `include` has
  distinct spans, so "span of the `SpecInclude` = span of its `SigSig`"
  identifies the derived form. `include A B C` becomes three `SpecInclude`s
  that all carry the span of the keyword alone (`parser.sml:1042-1043`, a
  bug: the names' positions are lost). `functor F (specs)` has
  `param = NONE`.
* **Signatures must be shown from the source text.** There is no signature
  printer. `Ast.tyToString` over-parenthesises (`(('a) list -> bool)`),
  elaboration expands type abbreviations at their uses
  (`elaborate.sml:286-296`), and the elaborated environment is three maps
  by name: order and spans are gone (`src/elab/env.sml:6-28`). The AST also
  loses parentheses in types, `op`, infix status and `;`.
* **What elaboration does give.** `Elaborate.sigs` and `Elaborate.funs` hold
  every named signature and functor after `elabTop` (`elaborate.sml:12-19`);
  `SigMatch.match` fails with a catchable `Error.CompileError`; elaborating a
  synthesised `structure Fresh : CLAIM = S` checks an implementation claim,
  `where type` included (demonstrated). Members that come from `open`, a
  structure alias or a functor application exist only in the elaborated
  environment: 110 of the 201 top-level structures of `lib/basis` are aliases
  or functor applications. Stamps identify structure aliases, types and
  `exception E = E`, but **not** rebound values: `val null = null`
  (`lib/basis/list.sml:8`) gets a fresh stamp (`elaborate.sml:325-333`).
* **Only `Parser.parseTokensWith`, `parseFileWith` and `parseFile` are
  exported** (`parser.sml:20,1200,1203`); an expression can still be parsed
  by wrapping it in `val it = ...`. `Fixity.initial` is enough to parse every
  file of the corpus on its own.
* **`--dump-tokens` is not a lexer-only mode.** Its one use is
  `src/driver/main.sml:154`; compilation goes on afterwards, the tokens of the
  prelude and of demand-loaded files are printed too, and an `.rbc` is written
  next to the input unless `-o` is given.
* **Errors are fatal on first** (`Error.error` raises); `Error.warn`
  accumulates formatted strings. A doc tool needs its own accumulator.
* **Cost of the frontend.** Parsing the signature files of the library takes
  12 ms natively and 242 ms on `runevm`; elaborating the whole library
  (169 files) 0.17 s natively and 4.7 s on `runevm` (627 M instructions).
  `tests/basis` is 2.3 MB of source, 26 times the signatures; at the same
  rate parsing it takes about 6 s on `runevm` (not measured).
* **The MANIFEST reader lives in the driver** (`main.sml:40-139`). Moving it
  into a `structure BasisManifest` (135 lines) left 146 of 146 user programs
  byte-identical, grew the compiler's bytecode by 196 bytes and the bootstrap
  by 0.07%.

### The library, its signatures and its comments

* `lib/basis` has 170 `.sml` files (10,183 lines). 56 signature files
  `sig_*.sml` (2,184 lines) are **generated** by `scripts/gen-basis-sigs.sh`
  from the test oracle `tests/basis/spec-sigs/*.sml`; the transformation is a
  `sed` rename and a generated marker, `--check` runs in `make check-docs`,
  and a regeneration deletes every `sig_*.sml` first
  (`gen-basis-sigs.sh:115-116`). All 56 are token-identical to their source.
* **Counting signatures.** The oracle has 66 files; two are partial
  transcriptions (`BIN_IO_IMP`, `TEXT_IO_IMP`), so the specification has 64
  signatures, with 1,306 values and exceptions (1,344 with the two partial
  ones). The library declares 65: those 64 and its own `MONO_VECTOR_EQ`.
  Nine are hand-written because structures are sealed with them; against
  their `SPEC_` twins `INTEGER`, `WORD`, `STREAM_IO` and `MONO_ARRAY` are
  token-identical, `MONO_VECTOR` writes `'b` for `'a` in four folds,
  `MONO_VECTOR_SLICE` and `MONO_ARRAY_SLICE` order three folds differently,
  and `PRIM_IO` says `RuneIODesc.iodesc` for `OS.IO.iodesc` (the one real
  difference). `mono_sigs.sml` declares `MONO_ARRAY` twice, identically
  (lines 28 and 89).
* The generator strips comments before it computes the `requires` column, so
  doc comments cannot disturb the MANIFEST.
* **Signatures carry no per-member documentation today.** Of 935 comments
  (in 170 + 28 + 66 files), 258 are file headers, 58 generated markers, 67
  banners (`(* ---- lists ---- *)`), 359 stand before a declaration in a
  structure body and 9 before a spec; 52 trail a constructor (51 of them in
  `src`), 2 a record field. The API commentary sits above the `fun`s of the
  structure bodies: 258 attached comments in `lib/basis`, about 104 of them
  on names a signature specifies. The header of a signature file says where
  it was transcribed from and what had to be changed to make it legal SML.
* **Only 62 of 201 top-level structures are ascribed** (55 `: MONO_*`, 7
  `:>`). The reasons: the signatures arrived after the structures; 9
  signature files name the structure they would seal (among them `CHAR`,
  `STRING`, `OPTION`, `TIME`, `DATE`, `INTEGER`, `WORD`, `REAL`; 3 more
  transitively), which needs `-Name` entries and reordering inside the
  MANIFEST block that the generator owns; of the 127 unsealed structures that
  have a signature 47 export names beyond it (323 names) and 5 have extras
  that other library files use (`IEEEReal.scanNumeral`, `Int.digitValue`,
  `Time.micros`/`ofMicros`, `Posix.IO.FD.cloexec`; `IEEEReal : IEEE_REAL`
  breaks `real.sml:279`); and ascription costs compile time (List +16%,
  String +18%, Real +11% for a program that declares just that structure;
  emitted code is unchanged).
* The signature → structure map exists only in the tests:
  `tests/basis/*_sig.sml` has 303 lines `structure C : SPEC_X ... = S`. After
  dropping the `SPEC_*_IMP` lines and the lines that check one pair twice
  (`text_sig.sml:17,19`) they are 189 pairs of 186 structures (substructures
  such as `TextIO.StreamIO` included); 123 lines carry `where type`, and 3
  comments record aliases (`(* alias: LargeInt = IntInf *)`). **OPTIONAL is
  recorded nowhere in machine-readable form.**
* Matching every structure against every signature with the compiler
  (186 × 65 pairs, 74 s) finds the 189 intended pairs and 18 others: 15
  against the internal `MONO_VECTOR_EQ`, two that are true and undeclared
  (`IntInf : INTEGER`, `LargeInt : INT_INF`), and one accident
  (`Socket : GENERIC_SOCK`). Small signatures match everything.
* Shapes a page has to cope with: `include` (`INT_INF` includes `INTEGER` and
  adds 10 members, `BIN_IO` adds 3, the flag substructures of `POSIX_TTY`
  include `BIT_FLAGS`); substructures with a named signature
  (`structure Path : OS_PATH` in `OS`) and with an inline one
  (`structure Kind : sig ... end` on one line, `spec-sigs/OS_IO.sml:16`);
  signatures with twenty instances (`MONO_ARRAY`, `INTEGER`); the pairs
  `IO`/`IO` and `OS`/`OS` where a structure and a signature share a name;
  primed names (`socket` and `socket'` in the three socket families).

### The test suite

* Every check has a label `Structure.member/case`; test functors build it
  with `lab "member/case"` and are applied with `val name = "Int"`
  (`tests/basis/README.md:72-80`). The last run on Rune has 136,062 checks
  with 136,061 distinct labels: 135,074 `Structure.member/case`, 979
  `Struct:SIG/case` from the `_sig` tests, 9 without a structure
  (`io_functors.sml`).
* A static extractor (a stand-in for one on the compiler's parser) finds
  10,884 label sites, 34,167 after expanding the 317 functor applications:
  27,145 literal labels and 3,771 patterns with a computed case part. Every
  one of the 109,451 computed labels that ran matches a static pattern, and
  the 535 literal labels that did not run are all behind a run-time
  condition (`precision = NONE`, `if V.maxLen <= ...`). Members: 4,111
  statically = 4,111 dynamically; the 3,751 pairs the specification requires
  are among them. **Functor sites produce 80.7% of the checks**; the `mono.*`
  tests alone 69,592.
* **20 of the 10,884 sites break the convention** (1.0% of the checks): 11
  compute the member (`lab (member ^ "/" ^ c)` in `fn/integer_fn.sml` and
  `fn/word_fn.sml`, `"General." ^ name`, `"StringCvt." ^ name`, ...), 9 in
  `io_functors.sml` have no structure.
* Where `scripts/check-basis-coverage.sh`'s grep is not enough: comments and
  path strings look like labels (its set has 34 junk entries such as `a.b`
  and `10.0.0.1`), 134 checker aliases are scoped per file, and 723 sites
  (6.6%) go through helpers that are not plain aliases.
* Per member: median 5 static checks (max 116, `Real.fmt`), 538 members with
  exactly one. By kind: `T.eq` 6,829, `T.check` 1,404, `T.raises` 1,221
  (predicates name the exception: `isSubscript` 581, `isSysErr` 179,
  `isSize` 99, `isOverflow` 92), `T.eqReal` 503, `T.approx` 101.

### Readings, deviations and where they are written down

* `tests/basis/deviations.txt` has 464 entries (582 lines): HOST-BUG 340,
  WIDTH 59, XC1-NA 29, SPEC-AMBIGUOUS 23, HOST-ABSENT 7, HOST-FLAKY 6,
  RUNE-DEV 0. One entry is about Rune: `rune |
  Char.fromString/unescaped-double-quote | SPEC-AMBIGUOUS`. It means: the
  check expects `NONE`, Rune answers `SOME #"\""`, the check **fails** on Rune
  and the line explains it; `run-matrix.sh` also applies it to every `xc1:`
  configuration, and it becomes a stale-line failure the day Rune changes its
  reading. Where Rune takes the same reading as the suite there is no line at
  all, so **`deviations.txt` is not where Rune's readings are recorded.**
* They are recorded in comments. Every comment of the tests and of
  `lib/basis` was read, together with `docs/basis-compat.md`,
  `docs/language.md` and the spec-sig headers, and merged into
  [docgen-notes.tsv](docgen-notes.tsv), which seeds M10 and the authoring
  waves: **440 distinct notes on 61 signatures** (29 more only quote the
  text the code follows, 5 are stale remarks; 10 to 25 duplicates may be
  left). By kind: 235 readings of the text, 158 choices the specification
  leaves to the implementation, 24 transcription fixes, 18 deviations, 5
  limitations. REAL has 35, DATE 21, TEXT_IO 21, STRING 19, STREAM_IO 19,
  POSIX_FILE_SYS 19, CHAR 18, SOCKET 15. **329 are recorded in exactly one
  place**: 190 only in a test comment, 137 only in a comment inside a
  structure body, 12 only in the documents, 12 only in a spec-sig header.
  233 are pinned by a label that was verified against the last run (150 of
  the readings, none of the deviations). 204 notes sit in structure bodies
  and would move into doc comments; 160 of those appear in no document today.
* Classes worth naming: **transparent types** the specification keeps
  abstract (`Date.date` a record, `Time.time = int`, `OS.Process.status =
  int`, `syserror = int`, the Posix ids, `NetHostDB.in_addr = string`; so
  `val t : Time.time = 1500000` and `val e : OS.syserror = 2` compile on
  Rune, and 13 of the 18 deviations are in no document), **extra members**
  (`Time.micros`, `Unix.protect`, `StreamIO.mkOutstreamOver`,
  `signature MONO_VECTOR_EQ`), **constants** (`Array.maxLen` =
  `Vector.maxLen` = 100,000,000, `String.maxSize` = 2^30 - 1, 64-bit `Int`
  and `Word`, binary64 `Real`, microsecond `Time`), **transcription fixes**
  (`datatype bool = datatype bool`, SOCKET's `'sock_type sock_addr` slip,
  POSIX_ERROR's `eqtype syserror = OS.Process.syserror`).
* The sweeps also found what scattered notes cost: `WideString.scan` stops
  at an unescaped `"` while `String.scan` converts it (unrecorded);
  `runefile.sml:59-61` and `unix.sml:111-115` call `NO_BUF` the default
  while files open `BLOCK_BUF` (`textio.sml:109-119`; checked by running);
  stale comments in `posix_filesys.sml:135-138`, `word8.sml:1-3`, `os.sml:47`
  and `tests/basis/real.sml:2-10`; `docs/plans/basis.md:22` still lists
  `getNREAD`, `getATMARK` and the linger time as stubs (`socket.sml:247-269`
  implements them); `iodesc` and `WideTextIO` are described differently in
  `docs/basis-compat.md` and `docs/language.md`; three SPEC-AMBIGUOUS themes
  are missing from the Readings table of `docs/basis-compat.md`.
* Host lines: 63% name one `Structure.member` exactly, 89% map to members
  mechanically, 5% are `@section`/`@load` labels. Without WIDTH, XC1-NA and
  HOST-FLAKY (which describe the test infrastructure) 347 entries are left:
  MLton 71, SML/NJ 153 (64 bits) and 165 (32 bits), Poly/ML 107.

### The comment corpus against a draft of the comment language

A Markdown subset with reserved `Keyword:` paragraphs (the language of D3)
was run over all 935 comments by a probe built on the real lexer. No odd
backtick, no nested comment, no commented-out code, no collision with a
reserved keyword (the nearest is `NOTE:` in `initial.sml:3`). Every comment
opens with `(* `, none decorates its lines with stars, and 986 of 988
continuation lines sit exactly on the text margin. 75 comments hold 103 code
spans (21 wrap over a line end); 108 unquoted `X.y` occur in prose. The house
style is "Subject: explanation" (`Char: 8-bit characters.`, `rule 19:`), so
an unknown `Word:` must never be a diagnostic; 115 comments quote the
specification in double quotes; `'a`, `[...]`, `|`, `foo_bar`, `<kind>`,
`\uXXXX` and `==>` all occur as plain text, so they must stay literal. About
794 of the 810 prose comments render correctly as they are. The problem that
is left is placement, not grammar: 8 of the 9 comments before a spec are
**group labels** (`(* IMPERATIVE_IO *)`), which Haddock placement would turn
into the documentation of the next `val`, and an own-line comment between
constructors means the next constructor in `token.sml` and the previous one in
`types.sml:23`.

### Prior art

Source-level review; sigdoc and PolyDoc were built and run on probe files.

| Tool | What it does | What goes wrong |
|---|---|---|
| sigdoc (Elsman) | One `(** *)` comment before and one after each signature; entries `[take (l, i)] returns ...` matched to vals; structures linked to their signature; HTML with a search box | The whole file is one regex; heads are matched by **substring** (`[app f l]` and `[map f l]` both anchor as `f` when `val f` exists; a line `[1,2,3]` becomes an entry); a missing trailer swallows the next signature |
| ML-Doc (Reppy; made the Basis site and book) | SGML is the source and signatures are extracted from it; `PROTOTY` call patterns with `<ARG>` names; several vals under one comment; per-constructor comments; instances with status REQUIRED/OPTIONAL and `where type`; merged index files; HTML and LaTeX | Docs are the source of truth (we invert that); only the first id of a group gets an anchor; `RAISES` is recorded and never shown; unresolved references give an empty link and exit 0 |
| PolyDoc | Parser lifted from Poly/ML; `(*!` comments; XML per file | Comments sit in a buffer the parser flushes at fixed points: a trailing comment lands on the **next** spec, comments leak across signatures, and `skipToEnd` loses the rest of a file silently; text in backquotes is not escaped |
| SMLDoc (SML#) | Javadoc tags, `@params` naming curried arguments, comments in a side list attached by region, per-constructor and per-field docs, `ModuleRef (defining path, displayed path)` | Nearest comment wins and the others vanish; no blank-line rule, no trailing form; `@param` names are never checked against the type; a parse error truncates the file silently; structure pages are empty for `S :> SIG = T` |
| smlnj-lib docs | Hand-written AsciiDoc in the Basis layout plus "Instances"; anchors `val:name`, files `sig-`/`str-`/`fun-` | Not extracted from source |

None of them resolves a value mentioned in prose through real environments,
none reports a comment it could not attach, none has tests for attachment or
markup. Taken over: signature-centred pages that list their instances; call
patterns, but **parsed and checked**; one comment for a run of specs;
per-constructor and per-field docs; link target separate from the displayed
path; following a structure to its signature (`List.map` lands on LIST);
status markers; an index per namespace; golden tests from the first day.

The Basis documentation of the other systems: MLton has one page of its own
that lists the top-level types, exceptions, values and overloads, every
`structure X : SIG`, the **type equivalences** and its deviations, and points
to the standard pages for the rest; Poly/ML has a summary page per kind with
little per-value text and notes on precision and platforms; SML/NJ ships the
standard pages (not checked further) and documents its own library as above.
The idea taken from them is MLton's: equivalences, optional modules and
deviations in one place.

What the Basis site has: Synopsis, Interface (one block, every identifier
linked down), Description keyed by call form, See Also, Discussion. What it
lacks and others have: the type at the entry (Haddock, odoc), thematic
sections and a contents line (Haddock, OCaml, Elm), exceptions as a field
rather than prose (odoc `@raise`, Rust `# Panics`), examples that run (Rust,
Go, Elixir, Elm), laws in code (Python's "roughly equivalent"), complexity
(Data.Map), a one-line summary table (Elixir), source and test links.

### GitHub Markdown, as far as it could be checked without pushing

* Generated heading anchors are useless for SML: lowercased, punctuation
  dropped (`@` gets an empty id, `::` and `<=` get `-1`, `-2`; `toString`
  and `tostring` collide).
* `<a name="x"></a>` is documented and on the sanitiser's allow-list; on real
  pages ids come out lowercased and the client lowercases the fragment, so
  **anchors must be unique ignoring case**. A link target containing `:` is
  stripped.
* `<details>`, tables with `\|`, `<br>` and `<code><a>` in cells work. Links
  inside a fenced block do not; `<pre>` with `<a>` inside works (confirmed
  with the rendering API only) but loses highlighting: links **or** colours.
* Keep a page under about 150 KB; beyond that GitHub loads the rendering
  lazily or truncates it (the exact limit is not documented).
* `LIST.md` next to `List.md` is fine on GitHub and breaks a clone on macOS
  and Windows; file names must be unique ignoring case.

## Constraints for all items

* `make check` is green after every numbered item below (M1.1, M1.2, ...),
  and each is its own commit. The bootstrap fixed point holds and all five
  builds emit identical bytecode. A change to `src/frontend`, `src/elab`,
  `src/util` or `src/driver` that docgen needs is landed first and alone,
  proven bytecode-neutral for user programs (`make check-cross`, `cmp` of
  `tests/out/*.rbc`), with the test `AGENTS.md` asks for.
* Docgen obeys the portability rules of `docs/building.md:191-215`: Basis
  only, only `structure`/`signature`/`functor` at top level, no dependence on
  the width of `int`, iteration through `StringMap`/`IntMap`, inside the
  language of `docs/language.md`. `docs/architecture.md` and
  `docs/building.md` describe it from M2 on.
* **Determinism.** The same input gives the same bytes from every build of
  docgen; nothing in the output depends on time, paths outside the
  repository, map order or the host.
* **Generated documentation is committed** and `make check-docs` fails when
  it is stale, as for `lib/basis/sig_*.sml` today. No line numbers appear in
  committed output, so that editing a test does not touch dozens of pages.
* **Docgen never reads `tests/basis/deviations.txt`** or anything under
  `tests/out`. It reads sources whose conventions are documented: the
  library, the MANIFEST and the labels of the test programs.
* **Every comment in a documented signature is accounted for:** attached,
  a section, or a diagnostic. No comment is dropped silently.
* **Original prose.** The pages of the specification and the book of Gansner
  and Reppy are copyrighted. Descriptions are written from the behaviour and
  in our own words; the specification is quoted only inside a note that
  discusses its wording, briefly and in double quotes, as the sources do
  today. The 29 inventory rows that only quote the text are not migrated.
* The contract of `AGENTS.md` stays in force and grows by one clause with the
  pilot wave (M6): a member added to a documented signature needs a doc
  comment.
* Two perf budgets in `tests/perf`: docgen over a fixed corpus in `tests/doc`
  (not over the library, which grows with every wave), and `compile-sigs`, a
  program that names ten signatures, which guards the cost that doc comments
  add to users' compiles.

## Design decisions

### D0. What is documented

A library is a directory with a MANIFEST. Its public names are the
`provides` column without the names that start with `Rune`, plus the
top-level environment (`initial.sml`, `pervasive.sml`). **The signature is
the unit of documentation**: there is a page per signature and per functor of
the specification, and none per structure. A structure appears on the page of
the signature it implements (D7), in `structures.md` and in the index; the
names it exports beyond its signature are listed in `structures.md` and each
needs a `Deviation:` note once its signature is on the ratchet list (D10).
The library's own overview and the grouping of its modules into areas come
from `lib/basis/overview.doc`, a text file in the comment language, and from
an `Area:` paragraph in each signature's header. Docgen takes the library,
the output directory and the test directory as arguments and knows nothing
about the Basis Library by name.

### D1. Where the doc comments live (open: the owner picks)

The 56 generated signature files leave no hand-maintained signature source
inside the library. Three ways out:

| | A. Flip the generator | B. Document the oracle | B'. Document the oracle, strip on generation |
|---|---|---|---|
| Doc comments live in | `lib/basis/sig_*.sml` and the hand-written signature files: one directory, 65 signatures alike | `tests/basis/spec-sigs` for 56, `lib/basis` for 9 | as B |
| `gen-basis-sigs.sh` | never overwrites an existing `sig_*.sml`; `--check` compares **tokens** after the `SPEC_` rename; still writes the MANIFEST block and the skeleton of a new signature | unchanged; `sed` carries comments through, so every note exists twice | strips comments; the library's files stay bare |
| The oracle | stays a lean transcription that is read against the page | grows about 15-fold with prose about Rune | as B |
| A signature edit | in both files; the token check catches drift (the specification has been frozen since 2004) | in one file | in one file |
| Compile-time cost | below | the same as A | none |
| "Source" link of a page | the library | a test file | a test file |

Measured cost of comments (960 comment lines before 120 specs in four
files): every bytecode file stays byte-identical; a program that names no
signature pays nothing (`hello`: +0); a program naming INTEGER, LIST, STRING
and WORD goes from 103.86 M to 110.00 M instructions (+5.9%, 782 to 805 ms);
the bootstrap +0.40%. The lexer spends 92.8 instructions per comment byte,
65 in `skipComment` and 27.7 in `computeLineStarts`, both allocating a tuple
per character; a one-argument skipper measured 23 without allocating. At 720
bytes of documentation per member, a program that loads ten signatures pays
about +16 M instructions (90 ms on `bin/rune`) and the bootstrap +32 M
(+3.8%, more than the 1.23% of headroom its budget has). Naming `OS` loads 6
signature files, `TextIO` 5.

**Recommendation: A**, after the lexer's two per-character loops are fixed
(M1.1; compiler bytecode only; the bootstrap budget is re-recorded once). The
specification's own wording ("comments at the very top of an .sml file /
signature") and the wish that the compiler checks comments one day both
point at the sources the compiler compiles, a page should link to the
library and not to a test, and the oracle keeps its purpose. B' is the
fallback if the measured cost after M1.1 is still unwelcome. With A the
cosmetic differences of the hand-written MONO signatures and the duplicate
`MONO_ARRAY` are removed so that the token check covers them, and
`PRIM_IO`'s `RuneIODesc.iodesc` is the one documented exception of the
check. The transcription headers stay in the oracle; in the library they are
what a page shows until the signature's wave replaces them with an overview
and turns their remarks into `Erratum:` notes.

Whatever is chosen, comments in **structure** files are documentation in
three places (the numbers of an instance do not belong in a signature that
`Int`, `Int32` and `IntInf` share): the header comment of a structure file
describes that instance; a comment directly above a `structure X = ...`
binding inside a structure (`structure Path = RunePath` in `os.sml`)
describes that substructure; and a note (D5) attached to the declaration of a
specified member is shown under that member as "In `Int`: ...". A note in the
body of a functor holds for every structure that is an application of it
(`Int8` to `Int32` through `RuneIntNFn`). Other comments in structure bodies
stay internal. `initial.sml` and `pervasive.sml` are the exception: they have
no signature, so the comments above their declarations document the
top-level environment, for the few names that are not twins of a documented
member (D7).

### D2. Capturing and attaching comments

Docgen rescans the gaps between tokens; its scanner mirrors `skipComment`,
and a gap whose residue is not whitespace is an `Error.bug`. The lexer is
untouched until the compiler is to check comments itself. Attachment is by
line, because that is how the sources are written (field comments come after
the comma, `unix.sml`):

1. The first comment of a file, not counting a generated marker, documents
   the first declaration when no blank line separates them; so does any
   comment directly above a `signature`, `structure` or `functor`.
2. A comment on its own lines, directly above an item (no blank line),
   documents that item: a spec, a description after `and`, a constructor on
   its own line, a field, a substructure.
3. A comment that follows an item on the line of the item's last token
   documents that item; a comma or a `|` between them does not matter. When
   several items end with that token it is the innermost: in `datatype order
   = LESS | EQUAL | GREATER (* ... *)` the constructor `GREATER`, not the
   datatype; to document the datatype, write the comment above it. An
   own-line comment inside a datatype documents the **next** constructor.
4. A comment may document a run of adjacent specs (no blank line and no other
   comment between them) when it has a usage head (D3) for each; all of them
   get an anchor.
5. A comment that starts with `----` (the banners of today) is a section
   heading: `(* ---- Taking lists apart ---- *)` becomes an H2 and an entry of
   the contents line. A comment followed by a blank line is a prose chunk of
   the section it stands in.
6. Inside a documented signature anything else is an error that names the
   comment; in a structure body it is ignored.

Fields can be documented wherever a record type is written in a spec: the
argument of a constructor or of an exception (`exception Io of {...}`), a
type abbreviation (the readers and writers of `PRIM_IO`), the argument of a
value. The 13 group labels of the corpus are rewritten as `----` headings in
M3; the lint warns about a value's comment that neither names the value nor
starts with a usage head.

The Interface block is the source text of the signature, token by token,
without the comments, with binding occurrences linked down the page; no
pretty-printer is needed and the author's layout survives. `type t = ty` is
recognised by span equality. The one frontend change is the fix of
`include A B C` (M1.2); field labels are found in the token vector.

### D3. The comment language

Plain prose is always correct. The language is a small subset of Markdown
with reserved paragraphs; everything else is literal text, and the renderer
escapes what Markdown would take for markup (`* _ < # [ \ |`).

* **Blocks:** paragraphs separated by blank lines; a code block is indented
  by 4 or more against the comment's text margin and follows a blank line; a
  list has lines starting with `- ` and follows a blank line. There are no
  headings, no emphasis, no HTML and no link syntax; a bare URL is a link.
* **Code spans** in backquotes may wrap over a line end. A span that lexes as
  one (long) identifier is a **reference**, resolved from the inside out:
  the usage head's argument names, the members of the signature, the
  enclosing signature, the library's modules, the top-level environment. A
  structure member resolves to its signature's page (`List.map` lands on
  LIST); the text shown stays as written. Until M8 resolution is by name
  within the documented library; from M8 it goes through the elaborated
  environments.
* **Usage heads.** When the first paragraph of a value's comment begins with
  a code span that parses (compiler's parser, top-level fixity) as the
  documented identifier applied to arguments, it is the call pattern:
  `` `take (l, i)` returns ... ``, `` `l @ m` is ... ``, `` `<< (w, n)` ``
  for a symbolic identifier that is not infix. The head is unqualified. It is
  checked against the spec's type: tuple arity, record labels, and the number
  of curried arguments, where arguments beyond the visible arrows are allowed
  when the result is a type constructor that may abbreviate a function type
  (`scan getc strm` against `(char, 'a) StringCvt.reader -> (int, 'a)
  StringCvt.reader`) until M8 expands abbreviations and checks exactly. It
  names the arguments for the rest of the comment, and the page shows it. A
  head is expected only of values whose type is an arrow; constants
  (`maxInt`, `pi`, `stdIn`) and exceptions have none. The first paragraph is
  also the one-line summary of the index tables.
* **Reserved paragraphs:** a closed, case-sensitive set, recognised only at
  the start of a paragraph of an attached doc comment.

  | Paragraph | Where | Content, and what is checked |
  |---|---|---|
  | `Raises:` | value | an exception in backquotes, then the condition; the exception must resolve; one paragraph per exception |
  | `Example:` | any | code; from M12 an `e = v` line is run |
  | `Law:` | value | an equation in code |
  | `Complexity:` | value | prose |
  | `See also:` | any | references; all must resolve |
  | `Area:` | signature, functor | the area of the overview page it is listed under |
  | `Status:` | module | `required`, `optional` or `extension`; a signature without one is required, a structure without one has the status of its signature |
  | `Implements:` | structure, functor | a signature expression, `where type` included, `opaque` optional; checked (D7) |
  | `Reading:`, `Erratum:`, `Deviation:`, `Implementation:`, `Limitation:` | any | a note (D5): its id in backquotes, then prose; `Reading (the suite differs):` is the one modifier |
  | `Pinned by:` | directly after a note | label globs in backquotes; each must match a label that exists (from M10) |

* **Diagnostics.** Errors: a malformed reserved paragraph, an odd backquote,
  a usage head that does not fit the type, an unattachable comment in a
  documented signature, a reserved paragraph where it does not belong.
  Warnings, which are errors for a signature on the ratchet list (D10): an
  unresolved qualified reference, a member without documentation, an
  arrow-typed value without a usage head, a first paragraph over 160
  characters. Never a diagnostic: an unknown `Word:`, an unqualified word in
  backquotes, anything in a comment inside an expression (those are not
  parsed at all). In `src`, where nothing is documented, the lint checks the
  grammar only.
* The checker depends on nothing beyond what the parser already needs
  (`src/util`, `src/frontend`, and the files of `src/elab` that `Ast` uses),
  so that the compiler can take it in later without taking docgen.

The documented signature that the mock page was written from starts like
this:

```sml
(* Polymorphic, immutable, singly linked lists. A list is either `nil`
   (written `[]`) or an element consed onto a list with `::`; ...

   Area: Lists *)
signature LIST =
sig
  (* ---- Types and exceptions ---- *)

  (* The type of lists, the one of the top-level environment.

     Erratum: `LIST/list-spec`. The specification writes the datatype out.
     The Definition (Section 2.9) does not allow `nil` and `::` to be
     specified, so the signature replicates the top-level datatype. *)
  datatype list = datatype list

  (* ---- Taking lists apart ---- *)

  (* `take (l, i)` is the list of the first `i` elements of `l`;
     `take (l, length l)` is `l`.

     Raises: `Subscript` if `i < 0` or `i > length l`.

     Law: `take (l, i) @ drop (l, i) = l` for `0 <= i <= length l` *)
  val take : 'a list * int -> 'a list
  ...
```

### D4. Packaging (open: the owner picks)

| | A second executable `runedoc` | A mode of `rune` |
|---|---|---|
| Sources | `sources-doc.txt`: `src/util`, `src/frontend`, `src/elab` and the generated `src/backend/prims.sml` (about 4,900 lines, the closure the spike built) plus `src/doc/*.sml` | about 3,000 lines more in `sources.txt` |
| Bootstrap budget (849.0 M of 859.5 M used) | untouched | +240 to 265 M instructions (+28 to 31%, at a measured 86 to 88 K per source line); the headroom is gone after about 120 lines |
| Every compile | nothing | `rune.rbc` +157 KB |
| Builds | MLton 12 s (`rune`: 15 s), SML/NJ 4.3 s, SML/NJ 32 bits 3.8 s, Poly/ML 1.6 s, self-hosted 5.35 s (734 M instructions); all five built at the first attempt and print byte-identical output | MLton +8 s on the critical path, about +2 s per bootstrap and per `check-cross` job |
| Plumbing | `scripts/gen-build-files.sh` parameterised (a 95-line diff that leaves the build files of `rune` byte-identical), four Makefile rules and a wrapper, the SML/NJ builds serialised (they share `.cm` directories) | `src/driver/options.sml`, `main.sml`, man page, completions |
| Needed from the driver | the MANIFEST reader as `structure BasisManifest` (proven neutral, above) | the same |

**Recommendation: `runedoc`**, built by all five hosts (it is one more loop
iteration, and five identical outputs are the determinism check that
`check-cross` gives the compiler). It also matches "not have the compiler
waste time on that". It is a tool of the repository at first: installation,
a man page and completions wait until it documents a library outside it
(M12).

### D5. Readings and deviations: the dependency, turned round

Today a reading is written in a test comment, perhaps again in a library
comment, perhaps in `docs/basis-compat.md`, and `deviations.txt` knows only
the one the suite fails. The doc comment becomes the one place:

* A **note** is a reserved paragraph: `Reading:` (the text is silent,
  ambiguous or contradicts itself, and this is what we take it to say),
  `Erratum:` (the page is wrong, transcription fixes included),
  `Deviation:` (Rune departs), `Implementation:` (a choice the specification
  leaves open, with its value), `Limitation:` (not there, or a stub).
* Its **id** is `scope/slug`, where the scope is `Structure.member`,
  `SIG.member`, `Struct:SIG` or `SIG`, and the slug is words joined by `-`:
  `Char.fromString/unescaped-double-quote`, `LIST/list-spec`. When one check
  pins the note the id is that check's label; otherwise `Pinned by:` lists
  the label globs, and a note without either is unpinned. A note the suite
  contradicts says `Reading (the suite differs):`.
* Docgen writes every note to `notes.tsv` (id, kind, signature, member,
  structures, whether the suite differs, label globs, source file, text) and
  renders `readings.md`.
* `tests/basis/check-notes.sh`, run by `make check-docs`, runs `runedoc` for
  the notes and the labels (D6) and reads `deviations.txt`. The arrow points
  from the tests to the documentation's export, never back:
  1. every `rune` entry of category RUNE-DEV or SPEC-AMBIGUOUS matches a note
     that says the suite differs, and every such note has an entry;
  2. for a signature on the ratchet list, the label of every SPEC-AMBIGUOUS
     host entry about it matches a `Reading:`;
  3. every label glob of a note matches a label that exists;
  4. a `Deviation:` or `Limitation:` that nothing pins is listed as unpinned
     in `coverage.md` (all 18 + 5 of today).
* `docs/basis-compat.md` keeps what is about the hosts and the matrix. Its
  sections "Representation choices in Rune", "Where Rune departs from the
  specification" and "Readings of the specification" become links to
  generated pages at the end of the last wave (M11.8), when every note has
  moved; the test comments that only restate a note shrink to a reference to
  its id as the waves pass.
* **Host bugs come last** (M12; the owner's choice during planning): docgen
  accepts a generic annotations file `member-glob | kind | text`, and an
  adapter under `tests/basis` makes it from `deviations.txt` (347 entries
  once WIDTH, XC1-NA and HOST-FLAKY are dropped; 89% map mechanically). The
  file is committed and checked for staleness like the generated signatures,
  so `make docs` still does not read `deviations.txt`; the price is a second,
  derived copy. They render as "Other implementations" under a member.

### D6. The test inventory

Static, with the compiler's lexer and parser, over a documented convention
(it goes into `tests/basis/README.md`): the first literal of a label contains
`Structure.member/` or is the argument of `lab`; the case part may be
computed; a functor's `val name` is a string literal; `Struct:SIG/case` is
the form of a signature check. The 20 violating sites are fixed. The
extractor resolves the per-file checker aliases (`val eqI = T.eq T.int`) and
expands functor applications, and gives each member: the number of check
sites, the case names and patterns (`take-drop-*`, marked as computed), the
kind of check, the exception of a `raises` check, and the test file.

* The wording is "checks that exist": 535 labels run only on some systems.
  The 6.6% of sites behind helper functions show as plain checks.
* **A functor site is listed once**, under the signature's member, as "in
  `fn/integer_fn.sml`, applied to `Int`, `Int8`, ... (9 structures)"; checks
  written for one structure are listed under that structure's name. Without
  this the page of `MONO_ARRAY` would repeat every check twenty times.
* The labels are not committed (about 31,000 rows that every test change
  would touch): `runedoc --labels` prints them, and `coverage.md` has the
  totals.
* Acceptance is differential: the extracted members equal those of
  `scripts/check-basis-coverage.sh` minus its 34 junk entries, and every
  label of a run matches a literal or a pattern. After that the coverage
  check is `runedoc --check-coverage` and the awk script goes.

### D7. Implementations

Declared, not inferred, and checked. Inference is nearly clean for the Basis
(18 strays in 12,090 pairs) but cannot give `where type`, status or aliases,
and small signatures match everything. Sealing the structures for the sake
of the documentation is rejected: MANIFEST cycles, extras that five files
depend on, and up to +18% compile time per structure.

* A claim is `Implements: INTEGER where type int = int`, with
  `Status: optional` if needed, in the comment that documents the structure:
  the file header, or the comment above the binding of a substructure
  (`structure Path = RunePath` carries `Implements: OS_PATH`), so that the
  claim sits where the public name is bound. A real ascription in the source
  counts as a claim.
* The claims are seeded mechanically from the 189 pairs of
  `tests/basis/*_sig.sml` and the list of optional modules of the
  specification; `IntInf : INTEGER` and `LargeInt : INT_INF` are added.
* Docgen writes them to `claims.tsv`; `tests/basis/check-claims.sh` (M7)
  compares that with the normalised `_sig.sml` lines, so that neither drifts.
* Until M8 a claim is checked by name (the signature exists). From M8 docgen
  elaborates a synthesised `structure Fresh : CLAIM = S` and reports the
  compiler's error.
* **Aliases and twins.** Structure aliases (`structure LargeInt = IntInf`),
  equal types and re-declared exceptions are found by identity of stamps
  after elaboration and give the type-equivalence table. A value twin
  (`List.null` is the top-level `null`) is recognised syntactically, as a
  binding `val x = longvid` whose right side resolves to the other value,
  because a rebound value gets a fresh stamp. Twins give the "top level"
  marks and let `top-level.md` take its descriptions from the signature's
  page.

### D8. Output

```
docs/generated/basis/
  README.md          the library's overview; areas and module hierarchy;
                     required/optional with Rune's status
  sig/LIST.md ...    one page per signature
  fun/StreamIO.md    the functors of the specification
  structures.md      structure -> signature, realisations, aliases (type
                     equivalences), names beyond the signature
  top-level.md       types, exceptions, values and their qualified twins;
                     overloads; infix table
  index/a.md ...     every identifier, a page per letter and one for symbols
  exceptions.md      every exception and who raises it (from Raises:)
  readings.md        every note, by kind and signature
  coverage.md        documentation coverage, test inventory totals, unpinned notes
  conventions.md     how to read a page, the notation, the anchor table
  notes.tsv claims.tsv   the machine-readable exports (D5, D7)
```

**A signature page**, in order (the mock shows it): title and breadcrumb; a
status table (required or optional, members implemented, documented, checks,
notes); Synopsis with every implementation, its realisations and its source
file; the overview from the header comment; a contents line of the sections;
the Interface block; the entries under their section headings; See also.

**An entry:** an H3 with an explicit anchor, the spec in a fenced block (so
it is highlighted), the description starting with the usage head, then
Raises, Law, Example, Complexity, the notes as block quotes, "In `Int`: ..."
instance notes, the "top level" mark, and the tests in a `<details>`.

**Datatypes and records** get the table the owner asked for, one row per
constructor and a nested row per field:

| Constructor | Argument | Description |
|---|---|---|
| `SCI` | `int option` | Scientific notation with the given number of digits after the point; `NONE` means 6. |
| `GEN` | `int option` | Whichever of `SCI` and `FIX` is shorter, with the given number of significant digits; `NONE` means 12. |

| Field of `decimal_approx` | Type | Description |
|---|---|---|
| `class` | `float_class` | Which kind of number this is; `digits` and `exp` matter only for `NORMAL` and `SUBNORMAL`. |
| `digits` | `int list` | The decimal digits of the mantissa, most significant first, each from 0 to 9. |

**Composite signatures.** An `include S` shows in the Interface as written,
linked; below the page's own entries an "Included from `S`" table lists the
inherited members with their summaries and links to `S`'s page; the status
table counts own and inherited members separately, and the index sends an
inherited member to the defining page. A substructure with a named signature
(`structure Path : OS_PATH`) is a row that links to that page with its
realisations; one with an inline signature (`structure Kind : sig ... end`)
is a section of the same page with anchors `val-kind.file`. A page with many
instances (`INTEGER`, `MONO_ARRAY`) has the instance table in its Synopsis
and instance notes under the members they concern.

**Anchors** are `<a name="kind-name">` with kind one of `type`, `con`,
`fld`, `exn`, `val`, `str`, the name lowercased over `[a-z0-9._-]` and `_`,
`'` spelled `-prime` (`val-socket-prime`), symbolic identifiers spelled out
by a fixed table that `conventions.md` prints (`val-op-at`,
`con-op-colon-colon`). Two anchors of a page that are equal ignoring case are
an error, as are two file names; there is no silent renumbering, so inbound
links stay stable. Every link docgen writes is checked against the anchors
it wrote. A page over 150 KB moves its test lists to `sig/NAME.tests.md`.

`make docs` writes the tree; `runedoc --check` regenerates into memory and
compares. Expected cost in `make check-docs` on `runevm`: 0.24 s for the
signatures, about 5 s for the elaboration (from M8), about 6 s for parsing
`tests/basis` (from M9; an estimate, to be measured in M9).

### D9. The intermediate representation

`structure DocIR`: the module tree; per entry its kind, name, source span,
the spec as tokens, the documentation as blocks and inlines, resolved
reference targets (defining path and displayed text), notes, test sites,
implementations, and `facts : (string * inline list) list`, the slot where
the results of later compile-time analyses (partiality, exceptions raised)
arrive without a change to the renderer. Three passes: extract (tokens, AST,
comments → IR), resolve (references, claims, tests, notes), render (IR →
Markdown). `--dump-ir` prints a stable text form for golden tests. Other
renderers (HTML, LaTeX) are later work and need output libraries first.

### D10. Writing the documentation

The 64 signatures of the specification name 1,306 values and exceptions,
besides types and constructors; `MONO_VECTOR_EQ` is documented with
`Status: extension`. "100%" in `coverage.md` means every member of those 65.
The waves, by area (values and exceptions):

| Wave | Signatures | Members |
|---|---|---:|
| W0, pilot | LIST, OPTION, BOOL, STRING_CVT, CHAR, INT_INF, OS_IO | 112 |
| W1, text and lists | LIST_PAIR, STRING, SUBSTRING, GENERAL, BYTE, TEXT, COMMAND_LINE | 106 |
| W2, numbers | INTEGER, WORD, REAL, MATH, IEEE_REAL, PACK_REAL, PACK_WORD | 165 |
| W3, sequences | VECTOR, VECTOR_SLICE, ARRAY, ARRAY_SLICE, ARRAY2, the five MONO signatures, MONO_VECTOR_EQ | 216 |
| W4, input and output | IO, PRIM_IO, STREAM_IO, TEXT_STREAM_IO, IMPERATIVE_IO, TEXT_IO, BIN_IO | 88 |
| W5, time and the system | TIME, DATE, TIMER, OS, OS_FILE_SYS, OS_PATH, OS_PROCESS | 116 |
| W6, Posix and Unix | POSIX and its eight parts, BIT_FLAGS, UNIX | 348 |
| W7, sockets | SOCKET, the three socket families, the three databases | 121 |
| W8, the rest | SML90, the top-level page, the functor pages, `overview.doc`, instance notes of the Wide and sized structures | 34 + |

* The pilot is chosen for what it exercises: CHAR brings the one `rune`
  entry of `deviations.txt` and 18 notes, STRING_CVT a datatype with
  arguments and the readers behind every `scan`, LIST the top-level twins,
  INT_INF an `include` and a signature with several instances, OS_IO a
  substructure with an inline signature and a record of fields. **The
  grammar of the comment language is frozen after the pilot** (M6), with the
  owner; **the page layout is frozen after M10**, when implementations,
  elaboration-backed links, tests and notes all show on the pilot's pages.
* A wave documents every member of its signatures, moves the notes of those
  signatures (from [docgen-notes.tsv](docgen-notes.tsv)) into the comments,
  reduces the test and library comments that restated them, and puts the
  signatures on the **ratchet list** `lib/basis/DOCUMENTED`: for a signature
  on it every warning of D3 is an error. `coverage.md` shows the rest.
* Examples that run are M12; until then an `Example:` is only rendered.

### D11. Testing docgen

`tests/doc/*.sml` with `.md`, `.ir` and `.diag` expectations, written by hand
or reviewed line by line like every `.expected`: attachment in every
position the corpus uses, the derived forms, `include`, both kinds of
substructure, groups, each reserved paragraph, each diagnostic, anchors of
symbolic and primed identifiers, escaping. A corpus lint
(`runedoc --lint lib/basis src`) in `make check-docs` keeps every comment of
the repository inside the language. `make check-cross` compares the output
of the five builds of docgen. The two perf budgets of the constraints.

### D12. Staging

Parse-only first (M2 to M7): pages, comments, claims checked by name, links
by name inside the documented library. Elaboration second (M8): references
through real environments, claims checked by the compiler, aliases, exact
usage heads. Each stage leaves committed documentation that is correct as
far as it goes.

## Milestones

Sizes as in [sml97.md](sml97.md): S about a day, M a few days, L a week or
more, XL several weeks. Every numbered item is one commit and leaves
`make check` green.

| | Content | Size | What it leaves verifiable |
|---|---|---|---|
| M0 | This roadmap, the spikes, the mock page, the notes inventory. Open: a rendering probe on a pushed branch (anchors, `<pre>` with links, `<details>`, page size) | done | the numbers above |
| M1.1 | The lexer's comment skipper and `computeLineStarts` without per-character allocation; a `tests/errors` test for the unterminated comment that `lex.comments` promises; bootstrap budget re-recorded | S | user bytecode identical; instructions per comment byte measured again |
| M1.2 | `include A B C` gets the spans of its names; an error test pins the position | S | user bytecode identical |
| M1.3 | `--dump-tokens` lexes the named files only, prints, writes nothing and exits 0 | S | `rune --dump-tokens f.sml` on a spec-sig file succeeds |
| M1.4 | With D1 = A: `gen-basis-sigs.sh` never overwrites a `sig_*.sml`, `--check` compares tokens, its messages say so, the generated markers go; the MONO signatures are aligned with the oracle and the duplicate `MONO_ARRAY` is removed | S | a comment added to `sig_list.sml` passes `check-docs`, a changed token fails it, rerunning the script changes nothing |
| M2.1 | `structure BasisManifest` out of the driver | S | user bytecode identical |
| M2.2 | With D4 = `runedoc`: `sources-doc.txt`, the parameterised build script, Makefile rules and wrapper for all five builds, a stub that parses its arguments; `docs/building.md`, `docs/architecture.md` | M | five builds exist and agree on the stub's output |
| M2.3 | `src/doc`: `DocIR`, extraction of bare signatures in source order with the derived forms, `include` and substructures recovered, `--dump-ir`; the `tests/doc` harness in `make check`; the docgen perf budget | M | five builds print the same IR for all 65 signatures |
| M3 | The gap scanner and the attachment rules of D2, section headings, groups, field labels from tokens, the accumulating diagnostics; the 13 group labels of the corpus become headings | M | goldens for every position |
| M4 | The comment language of D3: blocks, code spans, usage heads parsed by the compiler's parser and checked against the type, reserved paragraphs, the lint over `lib/basis` and `src` in `make check-docs`, the corpus fixes (about 16 comments) | M | zero errors on 935 comments; every diagnostic has a golden |
| M5.1 | The Markdown renderer: signature pages, Interface block, anchors, datatype and field tables, included members, substructures, `README.md`, the identifier index, `conventions.md`, `coverage.md`, link, anchor and size assertions | L | goldens; every link resolves |
| M5.2 | `make docs`, `runedoc --check` in `make check-docs`, the generated tree committed (undocumented: coverage 0%); the `compile-sigs` budget | S | the tree regenerates byte for byte |
| M6 | The pilot wave W0 (7 signatures, 112 members, their notes), `lib/basis/DOCUMENTED`, the `AGENTS.md` clause; the grammar is frozen with the owner | M | seven real pages; the ratchet holds for them |
| M7 | `Implements:` and `Status:` seeded from `tests/basis/*_sig.sml`, checked by name, `claims.tsv`, `tests/basis/check-claims.sh`; Synopsis tables, `structures.md` with the names beyond each signature, functor pages, instance notes from structure files and functor bodies | M | removing a claim fails `check-docs` |
| M8 | Elaboration: references through environments, claims checked by ascription, exact usage heads, aliases by stamp and value twins by syntax, `top-level.md`, `exceptions.md`, the type-equivalence table | M | a deliberately false claim and a dangling reference fail with the compiler's message |
| M9 | The label extractor, the convention in `tests/basis/README.md`, the 20 sites fixed, `runedoc --labels`, test lists on the pages with functor sites listed once, the differential acceptance, then `runedoc --check-coverage` replaces `scripts/check-basis-coverage.sh`; the cost in `check-docs` measured | M | identical member sets; every label of a run matches |
| M10 | Notes: `notes.tsv`, `readings.md`, `Pinned by:` checked, `tests/basis/check-notes.sh` in `make check-docs` with its check 2 limited to the ratchet list; the page layout is frozen with the owner | M | deleting the CHAR note, or the `rune` entry, fails `check-docs` |
| M11.1 to M11.8 | The waves W1 to W8, each with its notes. The last one replaces the three sections of `docs/basis-compat.md` by links and resolves the contradictions listed under "Where we are" | XL together | `coverage.md` reaches 100%, the ratchet list all 65 signatures, no unmigrated row in `docgen-notes.tsv` |
| M12 | Optional, in any order: host annotations through the generic input and the committed adapter output; examples that run (`Example:` lines `e = v` become a generated suite program per signature); installation, man page and completions of `runedoc` | M each | a host bug shows under its member; a wrong example fails `make test-basis` |

Dependencies beyond the order shown: M7, M8 and M9 each need only M5.2 and
can be done in any order; M10 needs M9 (its check 3 needs the labels). The
waves need M6 and can run beside M7 to M10; a note written before M10 is
parsed and rendered from M4 and M5 on, and checked from M10 on.

## Risks

1. **The writing is most of the work and stalls.** Waves, the ratchet and
   `coverage.md` make progress visible and keep what is done from rotting;
   the tool is useful from M5 with whatever is documented.
2. **A "plain comments" language is either too strict or means nothing.**
   The corpus run says the grammar fits; the closed keyword set, errors only
   in attached comments of documented signatures, and the pilot before the
   freeze guard the rest.
3. **Misattachment**, the failure of every earlier tool. Line-based rules
   with a stated tie-break, goldens for every position, and an error for
   every comment of a documented signature that attaches to nothing.
4. **Two copies of each signature drift** (D1 = A). The token check; the
   specification does not change. The generator must never again delete a
   signature file (M1.4).
5. **Comment cost at compile time** (D1 = A or B). M1.1 first, the
   `compile-sigs` budget after; B' stays possible because the comments are
   never load-bearing.
6. **A second executable strains the build.** All five builds worked at the
   first attempt; the diff of the build script is written.
7. **Committed output churns.** No line numbers, no dates, no committed label
   list, deterministic order; a change to a test's labels does touch its
   page, which is the point of the inventory.
8. **The static label extractor and the suite drift apart.** The documented
   convention, the differential gate of M9, and the coverage check sharing
   the extractor.
9. **The gap scanner and the lexer drift apart** once M1.1 rewrites
   `skipComment`. The `Error.bug` on a gap that is not whitespace and
   comments; the corpus lint runs over every file on every check.
10. **GitHub's rendering differs from what the API showed** (`<pre>` with
    links, lowercase anchors, the size limit). The probe of M0 before M5.1;
    the fallback is a fenced Interface without links plus the summary table.
11. **Copyright.** The rule of the constraints; quote-only notes are not
    migrated; notes quote briefly and attribute.
12. **`docs/basis-compat.md` and the pages disagree during the transition.**
    The pages link to it until M11.8 replaces the duplicated sections in one
    commit.
13. **The notes are more than they looked**: 440, 329 of them in one place
    only. They are spread over the waves by signature; REAL, DATE and TEXT_IO
    carry the most.

## Out of scope

HTML, LaTeX and any output that needs an XML or pretty-printing library;
search; compile-time analysis facts (the IR has the slot); the compiler
checking comments (the checker is built so that it can move); sealing the
library's structures; pages per structure; documentation of the compiler's
own sources beyond the lint; localisation; versioned documentation.

## Verification

* Per item: `make check`; for the neutral refactorings `cmp` of every
  `tests/out/*.rbc` before and after and `make bootstrap`.
* `runedoc --check` on a clean tree; touching a doc comment without
  `make docs` fails `make check-docs`.
* The five builds of docgen give byte-identical trees.
* The acceptance tests named in the milestone table: a changed token, a
  removed claim, a false claim, a dangling reference, a deleted note, a
  deleted `rune` entry, a wrong example each fail with a message that names
  the place.
* M9: the three-way comparison of label sets is rerun and gives the numbers
  of "Where we are" minus the junk entries.
* After the probe of M0: the pilot pages are read on GitHub, every anchor of
  a symbolic or primed identifier is clicked once.

## Where each line of the specification is answered

| Specification | Answered in |
|---|---|
| Generated from the source code; Basis first, under `docs/generated/basis` | D0, D8, M5 |
| At least as complete as the Basis site, best in class | Prior art, D8 (page anatomy), D10 |
| Review SML/NJ, Poly/ML, MLton, OCaml, Haskell and other languages and tools | Prior art (SML/NJ's own Basis pages were not looked at beyond noting that it ships the standard ones); what each does better is in D8 and the paragraphs of D3 |
| The ambiguities found, in the documentation, in sync, without depending on `deviations.txt` | Readings and deviations (where we are), D5, M10, M11; host bugs M12 |
| Reuse the compiler's parsing and infrastructure | The frontend (where we are), D2, D3 (usage heads), D4, D6, D7 |
| Later: analysis results in the documentation | D9 (`facts`), Out of scope |
| Overview, an entry per construct, structures and functors | D0, D7, D8 |
| Datatype tables with constructors and fields | D2 rules 2 and 3 and the field positions, D8 |
| Name, full type, description from the comments | D3, D8 |
| Comments are a formal language; plain prose is correct; special constructs are checked; docgen warns or errors | D3, the corpus run |
| Docgen checks now, the compiler later | D3 (the checker's dependencies), D2 (capture moves into the lexer then), D4 |
| Haddock placement: top of file, above a function, after a constructor or field | D2 |
| Signature-based, like sigdoc and PolyDoc; review them | D0, Prior art |
| Overview page with the module hierarchy and reference material | D0 (`overview.doc`, `Area:`), D8 (`README.md`, `top-level.md`, indexes, `conventions.md`) |
| A test inventory per signature, generated | The test suite (where we are), D6, M9 |
| Implementations listed per signature | D7, M7, M8 |
| Markdown with cross-links, rendered by GitHub | GitHub Markdown (where we are), D8 |
| An intermediate representation for other formats later | D9 |

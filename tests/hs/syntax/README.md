# The syntax tests of Haskell 98

The tests of the lexer, layout, parser and printers of `lib/language/haskell`
(`syntax.build`; the haskell98 roadmap's M11). Most run on rhc through the
runners of `tests/runner` (docs/testing.md, *rhc's tests*):

- `tests/hs/roundtrip/`: files the parser accepts, each held to the round
  trips of `tests/runner/hsroundtrip.sml` (`hs/roundtrip/rhc/...`): the tree
  and the token test of the explicit print and of the implicit one, and the
  exact print, byte for byte. `syntax/` holds a file for each part of the
  grammar of the Report's section 9.5 and of its lexical syntax, with
  literate files of both styles, comments and pragmas, a CRLF file, a byte
  order mark and a form feed; `cases/` the cases of E10 that the syntax
  accepts; `layout/` and `lexical/` a program for each row of the Report's
  layout (2.7 and 9.3) and of its lexical syntax (chapter 2) that the parser
  alone decides, named by its row as the conformance table names it
  (`ID_rest.hs`), with, where the Report or the row gives one, its expansion
  written by hand beside it (`ID_rest.braces`): the layout's braces and
  semicolons, or the tokens a lexeme splits into, written apart.
- `tests/hs/errors/`: files the syntax refuses, each with the text of its
  first diagnostic in `NAME.expected` (`hs/errors/...`): the lexer's, the
  literate reader's, layout's and the parser's (`lex-`, `lit-`, `lay-`,
  `parse-`), the cases of E10 that the syntax refuses (`cases-`), and the
  rows of the layout and the lexical syntax it refuses.

`cases.tsv` is E10's 46 crafted cases (the roadmap's evidence,
`results/E10/cases/`): each, whether the syntax of the Report as E10 read it
accepts it, and why. `r1-do-eq-eq` is accepted: operators stay flat, and
fixity resolution (M12) refuses it.

## The driver

`driver.build` builds `bin/rune-hs-syntax` on the library, for what the
runners of rhc do not hold it to (`tests/runner/hssyntax.sml`, the jobs
`hs/syntax/*`, `make test-hs-syntax`):

- `expansions DIR`: the tokens of the Report's L on each file with a
  `.braces` beside it are the tokens of that expansion, brace for brace and
  semicolon for semicolon, with no normalising (`hs/syntax/expansions`);
- `generate SEED N DEPTH`: the syntax generator of the roadmap's D55
  (`generate.sml`), random trees drawn by the productions of section 9.5,
  with random fixity declarations, each printed both ways, read back and
  compared with the tree drawn, and the two prints' tokens with each other
  (`hs/syntax/generated`, 2,500 trees from fixed seeds);
  `generate-files SEED N DIR` writes them as `gen-K.hs` and `gen-K.tree`,
  which the round trips of rhc read back (`hs/roundtrip/rhc/@generated`);
- the parser's mutants (`hs/syntax/mutants`): E10's five parser mutants, each
  an edit of `lib/language/haskell`, which the tree test cannot see and the
  token test must, and a lexer that drops a block comment, which only the
  exact print sees, each built and run over `tests/hs/roundtrip`;
- the cost of a token (`hs/syntax/budget`): what lexing and parsing the files
  of `tests/hs/roundtrip` costs in `runevm --count`'s instructions, bytes and
  objects, within `budget`;
- GHC's parser as an independent check of the tree's shape (`hs/syntax/ghc`,
  nightly, where `ghc` is there): GHC 9.4's dump of the parsed tree of a file
  is its dump of the file's explicit print, on `tests/hs/roundtrip` and on
  the files that `RUNE_HS_SYNTAX_GHC_LIST` names, E10's corpus; the
  differences known, by GHC's own readings or a pragma the print leaves
  out, are `ghc-dump.tsv`.

Its other commands are for a person: `check`, `roundtrip`, `explicit`,
`implicit`, `exact`, `tokens`, `dump`, `speed`, `cases`, `errors`, and
`--hier` to read dotted module names (D35), `--list FILE` for the files a
list names.

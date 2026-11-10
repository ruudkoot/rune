# The syntax tests of Haskell 98

The tests of the lexer, layout, parser and printers of `lib/language/haskell`
(`syntax.build`; the haskell98 roadmap's M11), until the round-trip harness of
`tests/runner` (M2) takes them over.

`driver.build` builds the driver, `driver.sml`, on the syntax alone. Its
commands:

| Command | What it does |
|---|---|
| `check FILE...` | parses each file: `OK`, or the first line of its first error |
| `roundtrip FILE...` | the round trips of each file, below: `OK` and a field for each test |
| `explicit FILE`, `implicit FILE`, `exact FILE` | the three prints of `HsPrint` |
| `tokens FILE` | the tokens of `L` of the file, the Report's layout function of section 9.3, as the parser read them |
| `speed N FILE...` | lexes and parses every file `N` times, for `runevm --count` |
| `dump FILE`, `dump-bare FILE` | the tree as text (`HsDump`), with spans and without |
| `cases DIR` | the crafted cases of `DIR/cases.tsv`, and the round trips of those accepted |
| `check-roundtrip FILE...` | the round trips, a line `FAIL` for each test a file fails |
| `errors DIR` | the diagnostics of `DIR` against their `.expected` |
| `generate SEED N DEPTH`, `generate-files SEED N DIR` | the syntax generator, below |

`--hier` reads dotted module names (D35), `--list FILE` stands for the files
that `FILE` names, a line each.

## The round trips

Each file the parser accepts is held to five tests (the roadmap's *Round
trips*, D28):

- **tree**, for the explicit print and the implicit one: parse, print, parse
  again, and the two trees are equal, read with no annotations;
- **token**, for both prints: the tokens of `L` of the print are those of `L`
  of the source, but for empty items and a trailing comma, which the tree does
  not keep. A parser that drops a field passes the tree test, since both sides
  lost it, and fails this one;
- **exact**: the exact print of the tree read with every annotation is the
  file, byte for byte, comments, pragmas, layout and all.

## The crafted cases

`cases/` holds the 46 cases of E10 (the roadmap's evidence,
`results/E10/cases/`): a directory each with its `Main.hs`, and in
`cases.tsv` whether the syntax of the Report, as E10 read it, accepts it,
and why. `r1-do-eq-eq` is accepted here: operators stay flat, and fixity
resolution (M12) refuses it.

## The other checks

- `errors/`: a file each that the front end refuses, `NAME.hs` or `NAME.lhs`,
  and in `NAME.expected` what the first line of its first diagnostic says
  (`FILE:LINE:COL: error: MESSAGE`; `errors DIR`), each reviewed by hand.
- `generate.sml`: the syntax generator of the roadmap's D55, random trees
  drawn by the productions of section 9.5 with random fixities, which
  `generate SEED N DEPTH` prints both ways, reads back and compares with
  the tree drawn, and the tokens of the two prints with each other;
  `generate-files SEED N DIR` writes them as `gen-K.hs` and `gen-K.tree`
  (the dump of `HsDump` with no spans) for a harness of its own.
- The mutants (`tests/runner/hssyntax.sml`, `hs/syntax/mutants`): E10's five
  parser mutants, each an edit of `lib/language/haskell`, which the tree
  test cannot see and the token test must; and a lexer that drops a block
  comment, which only the exact print sees.
- `budget`: the cost of a token, `hs/syntax/budget`.

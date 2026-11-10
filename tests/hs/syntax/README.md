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
| `cases DIR` | the crafted cases of `DIR/cases.tsv` |

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

# The names of rhc's programs

The tests of names, modules and fixity of the haskell98 roadmap's M12 (D29, D30, D35, D36), beside the clause
programs of `tests/hs/accept` and `tests/hs/errors`, which rhc now checks as far as names and fixity. Their jobs are
`hs/names/...` (`tests/runner/hsnames.sml`).

## Fixtures

Each directory here is a program whose `All.hs` imports the rest. Its expected files are what
`bin/rhc --dump-names` prints of it under a mode: `least.names` (`--names=least`, the default), `greatest.names`
(`--names=greatest`) and `dotted.names` (`--dotted-names`). Each file holds `pairs N`, the count of the dump's
`EXPORT` lines (a module and an entity it exports), and the lines that name a module of the program, or every line,
where its first line is `# whole`. The dump's lines are those `src/rhc/names.sml` describes: `EXPORT`, `FIX`,
`INSTANCE`, `ERROR`; an entity is its space, `v` or `t`, the identity of its module, and its name, a module of the
library being `haskell98:` and its name.

| Fixture | What it holds |
|---|---|
| `report` | The Report's 20 modules and rhc's two of primitives, whole: E16's 663 export pairs, 35 fixities and 164 instances (`results/E16/resolve.txt`), with the 20 pairs of the primitives, 683, and the 10 uses of 8 names that do not resolve as printed (`interact`'s in PreludeIO, Ratio's `numericEnum*`), until M17's overlay |
| `imp`, `gfp`, `cyc`, `hidden` | E16's fixtures (`results/E16/tests`): 690 pairs at the least fixpoint and 693 at the greatest on `imp`; one solution on `gfp`; least and greatest differ on `cyc`, 5 and 7, under a Prelude of the program's own; `hidden` refused |
| `char` | A program's own `Char`, which is not the library's |
| `fixity` | Fixity by entity, after names: a local operator, a qualified one, a local declaration, a constructor's in a pattern |
| `boot3` | E15's three signed modules, one cycle, which GHC refuses with and without boot files (`results/E15/run/boot3`) |
| `dotted` | A module `A.B` in `A/B.hs`, under `--dotted-names` (D35) |

`RUNE_TEST_ACCEPT=1 bin/rune-test run 'hs/names/*'` writes the expected files again from what rhc prints, keeping
their comments.

## Mutants

`hs/names/mutants` builds `driver.sml` with rhc's `src/rhc/library.sml`, `graph.sml` and `names.sml` and the library's
sources, each time with one edit, and each edit must change some fixture's dump: the greatest fixpoint for the least
(`imp`, `cyc`), a hidden module importable (`hidden`), fixity read by the name as written, before names (`fixity`).

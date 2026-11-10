# The types of rhc's programs

The tests of kinds, types, classes and recursive modules of the haskell98 roadmap's M13 (D30, D31, D32), beside the
clause programs of `tests/hs/accept` and `tests/hs/errors`, which rhc now checks through its type checker. Their jobs
are `hs/types/...` (`tests/runner/hsnames.sml`).

Each directory is a program whose `All.hs` imports the rest. Its expected files are what
`bin/rhc --dump-types --cycle-default=MODE` says of it, standard error's lines first: `module.types` for
`--cycle-default=module`, the default, and `scc.types` for `--cycle-default=scc`. The dump's lines are `TYPE`, a module of
the program, a value it defines and the value's type, and `LIBRARY-ERROR`, an error of the library's text.

| Fixture | What it holds |
|---|---|
| `report` | The Report's 20 modules, with rhc's overlay (M17): the Prelude's unit checks as one unit, `floatToDigits` with no annotation where its type depends on defaulting (E16), with no error |
| `cycle` | Two modules in a cycle: unsigned bindings mutually recursive across them, one binding group; a type group across them; an operator's fixity and a class's instance across the cycle |
| `tiebreak` | D30's tie-break case: a type variable whose predicates arose in two modules whose `default`s differ, refused under either setting |
| `rule2` | Rule 2 in a cycle: a restricted variable of one module fixed by another's use, refused under `module`, an `Int` under `scc` |
| `defaults` | A module's own `default` in a cycle: an `Int` under `module`; refused under `scc`, where the cycle's modules' `default`s differ |

`RUNE_TEST_ACCEPT=1 bin/rune-test run 'hs/types/*'` writes the expected files again from what rhc prints, keeping their
comments.

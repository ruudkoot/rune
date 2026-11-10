# HsLint's tests

The tests of HsLint, the independent check of rhc's types (the haskell98 roadmap's M16, D54; `lib/language/haskell`'s
`hslint.build`), beside the expectations of `tests/hs/accept`, `tests/hs/lang` and `tests/hs/errors`, which it is held
to as well. Their jobs are `hs/hslint/...` (`tests/runner/hslint.sml`; docs/testing.md, *HsLint*).

## Fixtures

Each program here, a file `NAME.hs` or a directory `NAME` whose `Main.hs` imports the rest, has the expected output of
`bin/rhc --dump-hslint` in `NAME.expected`, of `--dump-hslint --cycle-default=scc` in `NAME.scc.expected`, and of
`--dump-hslint=library` in `NAME.library.expected`, where those are. The dump's lines are those `src/rhc/lint.sml`
describes: `KIND`, `DERIVED`, `TYPE`, `SIGNED`, `DEFAULT`, or `REFUSED` and why. Each file was reviewed line by line.

| Fixture | What it pins |
|---|---|
| `restricted` | A restricted group whose members' types differ keeps its constrained variable open until the module is inferred, where Typing Haskell in Haskell's `split` would default it at once (D32, R20) |
| `rule2` | Rule 2 at the end of the module: 4.5.5's `len1` at `Rational`, E7's `n = 60` used at `Int` (R20) |
| `split` | A signature does not cut a group, and a signed variable's uses have its type: Typing Haskell in Haskell 11.6.3's `f` and `g` (R21(c)) |
| `onecontext` | One context for the variables of a group: `Num` on a variable that one member's type mentions is ambiguous and defaulted (R21(a)) |
| `defaults` | A module's `default` declaration, and 4.3.4's conditions (R22) |
| `simple` | 4.5.5's simple pattern binding: guards allowed, `(y)` and `~z` not simple (R18) |
| `classes` | Kinds inferred and defaulted (4.6), derived contexts by the fixpoint (4.3.3, 10.1), a synonym, a constructor class |
| `cycle` | A declaration group across a cycle of modules, each module's restricted binding fixed by itself (D30) |
| `cyclefix` | A module of a cycle fixing another's monomorphic type: refused under `--cycle-default=module`, the default, and taken under `scc` (D30) |
| `faults` | A program in which every rule of HsLint's comparison has a claim to check: held to its own expected dump by `--hslint-claims`, and refused by each rule with its fault (`hs/hslint/faults`) |
| `report` | The Report's library, every module a program may import with the Prelude's 11-module cycle, as one unit: its 7 unsigned values and the defaults its code chooses, among them `floatToDigits`'s (E16) |

`RUNE_TEST_ACCEPT=1 bin/rune-test run 'hs/hslint/dump/*'` writes the expected files again from what rhc prints; read
them line by line before committing.

## Disagreements

`disagreements.tsv` lists the programs of `tests/hs` on which HsLint and the program's expectation part, and why: a
reading, a bug of HsLint's, or a program that does not mean what it says. Each is held to still disagreeing, so that a
fix on either side shows; its line is removed then.

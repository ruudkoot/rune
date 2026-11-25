# A module's language

The tests of rhc's record of each module's edition and features (the haskell2010 roadmap's M4, *Tracking language
settings*; [docs/rhc.md](../../../docs/rhc.md), *A module's language*), run by `hs/language/*`
(`tests/runner/hslanguage.sml`; [docs/testing.md](../../../docs/testing.md), *A module's language*).

`cases/NAME` is a program and `cmd`, the arguments of `bin/rhc`, the program's root among them; `expected` is what it
prints, a unit at a time and `--whole` alike, at level 2: standard output, standard error, `status N`.

| Cases | What they show |
|---|---|
| `npk-*` | n+k patterns: Haskell 98's, off in Haskell 2010 by `-XHaskell2010` or a pragma, back by `NPlusKPatterns`, off in 98 by `-XNoNPlusKPatterns`; a module of 98 reads no other name of its header (`npk-98rule`); a module's own `Haskell98` beats the command line's edition, the command line's steps kept (`npk-pragma98*`) |
| `relaxed-*` | 4.5.1's example: refused in 98 (R21), accepted under Haskell 2010 or `-XRelaxedPolyRec`, and not by a pragma of a module of 98 |
| `mixed`, `cycle-*` | modules of both editions in one program, and in one recursive unit: only the bindings of the 98 module refused (`cycle-mixed`); HsLint at level 2 with every signature of such a cycle in scope from the start |
| `literate*` | a pragma read after unlit, and none in commentary |
| `unknown-*` | a name rhc does not know, at the name in a module of 2010, and on the command line |
| `shape-*` | the header's shapes: a lower-case keyword, comments, a pragma over lines, several pragmas, the last edition named, a pragma after `module` (not the header's) |
| `dotted-*` | an import of `Data.Thing` in a module of 2010, refused in one of 98, and read under `--dotted-names` |

The edit test's programs are written in the runner itself (`HsLanguageJobs.programs`).

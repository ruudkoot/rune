# rhc's Haskell 2010 corpus

The programs that rhc's Haskell 2010 mode is judged on beside its clause programs (the haskell2010 roadmap's M2, D39,
D40; *Testing and conformance*): E8's 3,217 candidates in seven sets, each judged by GHC 9.4.7 over the Report's
library (g10), GHC's own Haskell2010 over base (gbase), GHC's default language with each file's pragmas (gext),
MicroHs, Hugs `+98` and nhc98, after a filter that keeps untrusted code from every compiler. The oracles and the shim
are `tests/hs/oracles/README.md`'s (*The 2010 oracles*); the harness is `tests/runner/hsoracles2010.sml`, the filter
`tests/runner/hsfilter.sml`. What lands here is the judgements as data, the probes of the shim's limits, the survey of
the run tier's licences, the recipe of the Hackage set, and the 25 run programs that are new to 2010 with their
licences. The rest of the programs stay outside, in their trees, read through `RUNE_HS_CORPUS` (as the 98 corpus's
are: `tests/hs/corpus/README.md`) and, for Hackage, `RUNE_HS_HACKAGE`.

## The sets

| Set | Tree | Candidates | What it is |
|---|---|---:|---|
| `ghc-h2010` | `ghc` (GHC 9.14.1's testsuite) | 509 | every file whose LANGUAGE pragma names Haskell2010, and the two tests whose `all.T` passes `-XHaskell2010`; what each expects, from `all.T` |
| `nofib-2025` | `ghc/nofib` (b7391df) | 170 | a candidate per program directory; `run` where an expected output exists |
| `mhs-tests` | `MicroHs` (f17be7f) | 243 | `tests/*.hs`; `run` where its Makefile runs one plainly against its `.ref` |
| `mhs-src` | `MicroHs` | 1 | MicroHs's compiler, one program |
| `h98-corpus` | the 98 corpus's trees | 424 | the 98 corpus's 365 extension and 59 illegal-in-h98 rows: the extension corpus |
| `h98-accept` | the 98 corpus's trees | 1,441 | the 98 corpus's accept rows, judged by g10 and gbase only: are they 2010 programs? |
| `hackage` | `RUNE_HS_HACKAGE` | 429 | E7's 823 `closed2010` modules of Stackage LTS 24.67 as package components: compiled, never run |

## The files

| File | What it is |
|---|---|
| `trees.tsv` | each tree a set reads, its upstream, the commit E8 read (a job refuses a tree at another), its licence file, and its sets |
| `candidates.tsv` | E8's manifest: each candidate's root (a path under `RUNE_HS_CORPUS`, or `hackage/PACKAGE` under `RUNE_HS_HACKAGE`), its mains, what its suite expects, its flags, its run's arguments, input and output, and its parent (another directory its imports are found in; for Hackage, the component's source directories, `:` between them) |
| `judged.tsv` | E8's verdicts, a row a candidate: its shape, the extensions it names, the imports outside the Report, the filter's reasons (`untrusted`; `untrusted_late` for the two the filter caught after GHC had seen them with CPP off), whether g10's copy imports `RebindableH2010` (`rebind`), each oracle's `accept` or `reject` (empty where E8 did not ask it), and g10 against gbase (`class`) |
| `accept.tsv`, `reject.tsv` | E8's lists: the 1,279 plain candidates g10 accepts that their suites expect to compile (ghc-h2010 32, h98-accept 816, hackage 355, mhs-tests 27, nofib-2025 49), and the 882 plain ones it refuses, with g10's first complaint |
| `filtered.tsv` | the 167 candidates kept from every compiler, and why |
| `run.tsv` | the run tier: 90 programs built with `ghc -O0` (with g10 where g10 accepted, else gbase), each one's build, status, output against its expected one, CPU seconds and instructions |
| `extcorpus.tsv` | the extension corpus for track X: 1,198 (extension, candidate) rows, 84 extensions over 528 candidates GHC accepts with their own pragmas |
| `limits.tsv`, `limits/` | the 23 probes of what g10 reproduces of the Report: each probe's program, the Report's verdict and output, and each oracle's |
| `licences.tsv` | the survey of the run tier: each program's licence, where it is stated, and whether it is vendored or why it stays outside |
| `hackage.tsv` | the Hackage set's recipe: each of the 392 packages its components name, its tarball's URL and sha256 |
| `vendored/` | the 25 run programs new to 2010, under their trees' licences |

The data is E8's (the haskell2010 drafts' `results/E8/`), each path made relative to its root and the oracles' second
and later complaints left out of `judged.tsv`; nothing else is changed. Its counts are in the roadmap's E8.

## The filter (D40)

The filter runs before any compiler, on every module of a candidate's closure, and again on any corpus re-pinned
(`hs2010-corpus/filter` runs it over the trees and holds it to `filtered.tsv`). A candidate is kept out when a
module turns on Template Haskell (TemplateHaskell, TemplateHaskellQuotes, `-fth`) or QuasiQuotes, uses CPP (a pragma,
`-cpp`, or a directive line at a line's start, in a literate file too), imports by `capi` (GHC includes the header),
or names in its options a preprocessor, a plugin or an option file (`-F`, `-pgm...`, `-fplugin`, `-opt...`,
`-ghci-script`, `-package-env`, `-i`); in every copy compiled the pragmas ANN (GHC evaluates an annotation), INCLUDE
and OPTIONS are blanked, LANGUAGE too but in gext's copy. It kept 167 of the 3,217 out (CPP 129, TemplateHaskell 30,
QuasiQuotes 4, `capi` 3, options 4).

**By D40's B its CPP rule is a switch** (`HsFilter.cppAdmitted`, off until M20): CPP with `#include` stays out for
good; CPP without it is admitted to the oracles once rhc has CPP, a Hackage component's cabal flags read first (every
`ghc-options` word, and every `cpp-options` word as the `-optP` flag Cabal passes), so that the option rule refuses
them. With the switch off the filter is E8's as built. Counted on the trees by the filter as landed: of the 129 CPP
candidates, 37 include a file (ghc-h2010 2, h98-accept 18, nofib-2025 17) and 92 do not (nofib-2025 47, h98-accept
37, h98-corpus 5, ghc-h2010, hackage and mhs-tests 1 each); with the switch on 91 would be admitted, the Hackage one,
graphula's README, staying out for its cabal file's `-pgmL`. E8's `untrusted` column says `CPP#include` of 19 only,
since it names a module with a LANGUAGE CPP pragma `CPP` whatever it includes, so the roadmap's "110 without
`#include`, 63 of nofib's 64" is 92 and 47.

## The licences

The repository is CC0, which cannot cover another author's program; the owner's rules are those of
`tests/hs/corpus/README.md`: code not under CC0 lands with its licence beside it, code under no licence with a
`PROVENANCE`. Hackage is never vendored: each package has its own licence, and the set is a pinned recipe
(`hackage.tsv`), compiled nightly and never run. The trees' licences:

| Tree | Licence | Stated in |
|---|---|---|
| `ghc` | The Glasgow Haskell Compiler License, BSD-3 (the testsuite's own, three named tests GPL-3, none a run program) | `ghc/testsuite/LICENSE` |
| `ghc/nofib` | none stated: no `LICENSE`, and its `README.md` is silent | |
| `MicroHs` | Apache 2.0, Lennart Augustsson 2023-2026 | `MicroHs/LICENSE` (no `NOTICE`) |
| the 98 corpus's | as `tests/hs/corpus/README.md` surveys them | |

The survey is `licences.tsv`, a row for each of the run tier's 90 programs, made by reading each program's file and
its tree's licence. **Vendored are the 25 run programs new to 2010**: built with g10, right, in at most a second under
`ghc -O0`, and not nofib's (24 MicroHs tests and GHC's `deSugar/should_run/T18151`), each file as its tree has it at
the pinned commit (the main and its expected output), at its place in the tree, under its tree's `LICENSE` copied
beside it: `vendored/MicroHs/LICENSE` and `vendored/ghc/testsuite/LICENSE`. None of their files names another
holder. The other 65 stay outside: nofib's 49 (25 in the 98 run set, vendored there as nofib-2019's copy; 18 over a
second; 6 built over base only, not right, or not built), and 16 of MicroHs's and GHC's: 11 built over base only (threads,
`ByteString`, `Typeable` and the like: not programs of the Report's library) and 5 whose output is not what their
suites expect. `hs2010-corpus/data` holds `vendored/` to these 25 programs' files and their two notices and
nothing more, each file under the notice its row names; `hs2010-corpus/vendored` (nightly, with the trees) holds it to
the trees' bytes.

## Getting the trees

`RUNE_HS_CORPUS` is the 98 corpus's directory, with two trees more: GHC's at the commit `trees.tsv` pins, with its
`nofib` submodule checked out at its commit, and MicroHs's (`git clone https://github.com/augustss/MicroHs.git`, then
`git checkout f17be7f0ebcbec94ad40121bea79ca3bf6c85d3f`). `RUNE_HS_HACKAGE` is a directory holding each package of
`hackage.tsv` unpacked (`PACKAGE-VERSION/`), each tarball's sha256 checked first; the jobs that need it skip without it.

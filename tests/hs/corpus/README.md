# rhc's corpus

The programs that rhc is tested on beside its clause programs (the roadmap's *The suites: accept, reject and run*): the
3,089 candidates of nine sets that E8 judged under GHC 9.4.7 with the strict shim, Hugs `+98` and nhc98 `-98`, and
the 82 conformance tests that E7 built and ran on those three and on MicroHs. The repository is CC0, which cannot cover
another author's program, so the programs stay outside, in the trees `trees.tsv` pins, and the harness reads them
through a path, as `ExternalChecks` reads MLton's regression set: `RUNE_HS_CORPUS` names a directory that holds each
tree under the name of its `tree` column (`nhc98/`, `nofib/`, `ghc/`, ...). What lands here is this project's own:
the judgements as data, the survey of the licences, and the compat layer.

## The licences

The survey is `licences.tsv`, a row for every candidate, the 188 programs that D56 puts in `make check` first (`d56`
is `yes`): its licence, the file that states it (a path under `RUNE_HS_CORPUS`), and whether it may be vendored. It
was made by reading every file of each candidate's closure, and the data files beside its main, for a copyright, a
licence or a grant, and then the licence of its tree. A `note` is given where a row departs from its set's.

| Set | Tree | Licence | Stated in | Candidates | May be vendored |
|---|---|---|---|---:|---|
| `conformance98` | nhc98 | nhc98's licence, version 2, or the GNU GPL at the recipient's choice | `nhc98/COPYRIGHT` | 67 | yes, with `COPYRIGHT` [inferred coverage] |
| `yhc-conformance` | yhc | none stated for the tests | | 15 | no |
| `nhc98-nofib` | nhc98 | none stated: nofib's programs, which nhc98's `COPYRIGHT` does not claim | | 77 | no; `spectral/boyer` for the owner to read |
| `nofib-2019` | nofib | none stated: no `LICENSE`, and `README.md` is silent | | 168 | no; five for the owner to read: `spectral/boyer`, two `fulsom`s, two `cacheprof`s (GPL) |
| `ghc-legacy` | ghc | The Glasgow Haskell Compiler License, BSD-3 | `ghc/LICENSE` | 952 | yes, with `LICENSE` |
| `jhc` | jhc | MIT, John Meacham 2013 | `jhc/LICENSE` | 616 | yes, with `LICENSE` |
| `uhc-99` | uhc | The UHC License, BSD-2 | `uhc/EHC/LICENSE` | 155 | yes, with `LICENSE` |
| `hse` | haskell-src-exts | modified BSD, Niklas Broberg 2005 | `haskell-src-exts/LICENSE` | 226 | 224 yes; `ByteStringUtils.hs` and `HaddockComments.hs` state the GPL of their own |
| `helium` | helium | GNU GPL, version 3 | `helium/LICENSE.txt` | 813 | only under the GPL, which is the owner's to accept for files in this tree |

What the survey rests on:
- **nhc98's `COPYRIGHT`** names the compiler, its libraries and its tools, not the tests. The tests of `conformance98`
  ship in the same tree under no other notice, and the CVS log kept in some of its test files records the suite's
  addition by one of the holders it names, in 2004 (`malcolm`, "Add a regression testsuite for the nhc98 compiler",
  `tests/nofib/real/ebnf2ps/EbnfLayout.hs:5`), so its licence is taken to cover them [inferred]. It lets the files be
  redistributed unchanged with every notice and the licence kept, and a modified file only with its source, its
  changes described and its name changed.
- **nofib states no licence,** in either tree. 31 of its programs carry a notice in a file of their own (`common/
  NofibUtils.hs` aside, which the compat layer replaces). Six grant something in every file: `spectral/boyer` in both
  trees, whose `Status: Public Domain` is the line of the Lisp original it translates, a reading for the owner rather
  than a grant to the Haskell text; `real/fulsom` and `gc/fulsom`, Duncan Sinclair's permission notice; and
  `real/cacheprof` and `gc/cacheprof`, the GPL. The rest name a holder and grant nothing (`real/hpg`'s Crown
  Copyright, `spectral/multiplier`'s John T. O'Donnell), or grant for one file of several (`real/gamteb` and
  `real/pic`: the Regents of the University of California, in `GamtebMain.hs` and `Pic.hs` alone).
- **yhc's tree** has no licence file for its tests; `yhc/src/compiler98/yhc.cabal` says GPL for the compiler.
- **GHC, jhc, UHC and haskell-src-exts** state one licence for the repository, tests included. jhc's
  `1_typecheck/2_pass/ghc/` are copies of GHC's tests, which GHC's licence covers as well.

**The 188 of D56:**

| | Programs | Sets |
|---|---:|---|
| May be vendored, each with its tree's licence file | 74 | `conformance98` 27, `ghc-legacy` 32, `jhc` 15 |
| A public-domain line of an original, for the owner to read | 2 | `spectral/boyer` in both nofib trees |
| No licence stated: stay outside | 112 | `nhc98-nofib` 52, `nofib-2019` 50, `yhc-conformance` 10 |

So the larger part of D56's set cannot be vendored on any licence found, and **the owner chooses** between the
roadmap's two forms for those 188 (M3): vendored under `tests/hs/corpus/` with their licences, which can hold the 74
(and the two `boyer`s if their line is read as a grant), or a `Test.requires` that skips them where the corpus is
absent, which `make check` refuses as a skip today (`AGENTS.md`), so needs the corpus on every machine or a weaker
`make check`. Nothing here is vendored until the owner chooses. One precedent is in the tree already:
`examples/benchmarks/*/upstream/` holds nofib's originals for its ports, with `NOTICE` files that say "No separate
general redistribution grant is inferred from suite membership"; whether that extends to this corpus is the owner's.

The GHC shim of the oracles (`tests/hs/oracles/ghc-shim/`) holds three modules of GHC's libraries, `Random`,
`Locale` and `ShimTime` (from `random`, `old-locale` and `old-time`), under the BSD licence of GHC's `base`, which is
kept beside them as `BASE-LICENSE`; the rest of it is this project's.

## The files

| File | What it is |
|---|---|
| `trees.tsv` | each set's tree: its upstream, the commit E7 and E8 read, and its licence file |
| `licences.tsv` | the survey above, a row a candidate |

# rhc's corpus

The programs that rhc is tested on beside its clause programs (the roadmap's *The suites: accept, reject and run*): the
3,089 candidates of nine sets that E8 judged under GHC 9.4.7 with the strict shim, Hugs `+98` and nhc98 `-98`, and
the 82 conformance tests that E7 built and ran on those three and on MicroHs. The repository is CC0, which cannot cover
another author's program. The owner's rules: code not under CC0 may be vendored with its licence beside it ("You may
vendor non cc0 code by adding a LICENSE along side it."), and code under no licence with a provenance beside it ("If
you want to vendor code without a license add a PROVENANCE alongside it instead."). So the 188 programs of D56's set
are vendored in `vendored/`, copied from the trees at the commits `trees.tsv` pins, each tree or origin in a directory
of its own with a notice: the tree's `LICENSE`, copied with it, where the tree grants one, and otherwise a `PROVENANCE`
written here. The rest of the candidates stay outside, in those trees, and the harness reads them through a path, as
`ExternalChecks` reads MLton's regression set: `RUNE_HS_CORPUS` names a directory that holds each tree under the name
of its `tree` column (`nhc98/`, `nofib/`, `ghc/`, ...). The rest of what lands here is this project's own: the
judgements as data, the survey of the licences, the provenances, and the compat layer.

## The licences

The survey is `licences.tsv`, a row for every candidate, the 188 programs that D56 puts in `make check` first (`d56`
is `yes`): its licence, the file that states it (a path under `RUNE_HS_CORPUS`), and whether it is vendored
(`vendored`), may be with its tree's licence (`vendor`), states no licence and so could be only with a provenance
(`outside`), or is the owner's to read (`owner`); and for each vendored one its `notice`, the `LICENSE` or `PROVENANCE`
under `vendored/` that it lands under. It was made by reading every file of each candidate's closure, and the data
files beside its main, for a copyright, a licence or a grant, and then the licence of its tree. A `note` is given where
a row departs from its set's.

| Set | Tree | Licence | Stated in | Candidates | May be vendored |
|---|---|---|---|---:|---|
| `conformance98` | nhc98 | none plainly stated for the tests: nhc98's `COPYRIGHT` names the compiler, libraries and tools | | 67 | with a `PROVENANCE` |
| `yhc-conformance` | yhc | none stated for the tests | | 15 | with a `PROVENANCE` |
| `nhc98-nofib` | nhc98 | none stated: nofib's programs, which nhc98's `COPYRIGHT` does not claim | | 77 | with a `PROVENANCE` |
| `nofib-2019` | nofib | none stated: no `LICENSE`, and `README.md` is silent | | 168 | with a `PROVENANCE`; four for the owner to read: two `fulsom`s, two `cacheprof`s (GPL) |
| `ghc-legacy` | ghc | The Glasgow Haskell Compiler License, BSD-3, the testsuite's own (three named tests GPL-3, none a candidate) | `ghc/testsuite/LICENSE` | 952 | yes, with `LICENSE` |
| `jhc` | jhc | MIT, John Meacham 2013 | `jhc/LICENSE` | 616 | yes, with `LICENSE`; copies of another origin (a Shootout program, nofib's `primes`) with a `PROVENANCE` |
| `uhc-99` | uhc | The UHC License, BSD-2 | `uhc/EHC/LICENSE` | 155 | yes, with `LICENSE` |
| `hse` | haskell-src-exts | modified BSD, Niklas Broberg 2005 | `haskell-src-exts/LICENSE` | 226 | 224 yes; `ByteStringUtils.hs` and `HaddockComments.hs` state the GPL of their own |
| `helium` | helium | GNU GPL, version 3 | `helium/LICENSE.txt` | 813 | only under the GPL, which is the owner's to accept for files in this tree |

What the survey rests on:
- **nhc98's `COPYRIGHT`** names the compiler, its libraries, its runtime system and its tools, not the tests. The
  tests of `conformance98` ship in the same tree under no other notice, and the CVS log kept in some of its test files
  records the suite's addition by one of the holders it names, in 2004 (`malcolm`, "Add a regression testsuite for the
  nhc98 compiler", `tests/nofib/real/ebnf2ps/EbnfLayout.hs:5`). That makes a licence for them likely, but the text
  does not plainly grant one, so they are not vendored under it (M19-O7) but with a `PROVENANCE` (M19-O8).
- **nofib states no licence,** in either tree. 31 of its programs carry a notice in a file of their own
  (`common/NofibUtils.hs` aside, which the compat layer replaces). Six grant something in every file: `spectral/boyer`
  in both trees, whose `Status: Public Domain` is the line of the Lisp original it translates, a reading for the owner
  rather than a grant to the Haskell text (it is vendored with a `PROVENANCE`, which quotes the line); `real/fulsom`
  and `gc/fulsom`, Duncan Sinclair's permission notice; and `real/cacheprof` and `gc/cacheprof`, the GPL. The rest
  name a holder and grant nothing (`real/hpg`'s Crown Copyright, `spectral/multiplier`'s John T. O'Donnell), or grant
  for one file of several (`real/gamteb` and `real/pic`: the Regents of the University of California, in
  `GamtebMain.hs` and `Pic.hs` alone).
- **yhc's tree** has no licence file for its tests; `yhc/src/compiler98/yhc.cabal` says GPL for the compiler.
- **GHC, jhc, UHC and haskell-src-exts** state one licence for the repository, tests included; GHC's testsuite has a
  `LICENSE` of its own, GHC's licence with three tests named under the GPL-3 (none a candidate), and that file is the one
  kept beside them. jhc's `1_typecheck/2_pass/ghc/` are copies of GHC's tests, which GHC's licence covers as well. Two
  of jhc's run programs come from elsewhere, which jhc's licence cannot grant: `8_shootout/SumFile.hs`, "The Computer
  Language Shootout ... contributed by Greg Buchholz", and `9_nofib/spectral/Primes.hs`, nofib's `primes`; each is
  vendored with a `PROVENANCE` of its own directory, which stands nearer to it than jhc's `LICENSE`.

**The 188 of D56:**

| | Programs | Sets |
|---|---:|---|
| Under their tree's `LICENSE` | 45 | `ghc-legacy` 32, `jhc` 13 |
| With a `PROVENANCE`: no licence stated | 112 | `nhc98-nofib` 52, `nofib-2019` 50, `yhc-conformance` 10 |
| With a `PROVENANCE`: a licence not plainly stated for the tests | 27 | `conformance98` |
| With a `PROVENANCE`: a public-domain line of an original, which is the Lisp program's, not a grant | 2 | `spectral/boyer` in both nofib trees |
| With a `PROVENANCE`: another origin than its tree's | 2 | `jhc`'s `SumFile.hs` and `Primes.hs` |

The owner decided (M19-O7): "You may vendor non cc0 code by adding a LICENSE along side it."; and then (M19-O8): "If you
want to vendor code without a license add a PROVENANCE alongside it instead." All 188 are vendored, each file as its
tree has it at the pinned commit (its closure, or for the whole sets its program's directory without nofib's fast and
slow fixtures or the symbolic links to `common/NofibUtils.hs`, which is vendored once; its expected output and its
input), at its place in the tree, and stored as it is (`.gitattributes` turns off the conversion of line ends under
`vendored/`, for nofib's `real/hpg/README.nofib` has CR LF). Every file under `vendored/` is under one notice, the
nearest `LICENSE` or `PROVENANCE` in its directory or above it, and that is the notice its row of `licences.tsv` names:

| Directory of `vendored/` | Notice | Programs | Files |
|---|---|---:|---:|
| `ghc/testsuite/` | `LICENSE`, GHC's testsuite's (BSD-3), copied from the tree | 32 | 65 |
| `jhc/`, but for the two below | `LICENSE`, jhc's (MIT), copied from the tree | 13 | 26 |
| `jhc/regress/tests/8_shootout/` | `PROVENANCE`: the Shootout's `SumFile.hs`, its contributors as its header names them | 1 | 3 |
| `jhc/regress/tests/9_nofib/` | `PROVENANCE`: nofib's `primes`, as jhc keeps it | 1 | 2 |
| `nhc98/tests/conformance98/` | `PROVENANCE`: nhc98's own tests | 27 | 55 |
| `nhc98/tests/nofib/` | `PROVENANCE`: nhc98's copy of nofib | 53 | 314 |
| `nofib/` | `PROVENANCE`: nofib as GHC keeps it | 51 | 376 |
| `yhc/tests/conformance98/` | `PROVENANCE`: yhc's own tests | 10 | 21 |

A `PROVENANCE` gives the upstream repository and the commit `trees.tsv` pins, the path in it, the date the tree was
fetched and the files copied, why no licence covers the files (or what notice there is, quoted), the owner's rule,
quoted, and then each program: its files, by their paths below it (which it maps to their upstream paths), and what
their own headers name of its authors and origin, quoted by file and line. The runs of the 188 are `make check`'s
(`hs-corpus-run/ID`), but for those `tests/hs/corpus-nightly.txt` names, whose run in a way takes over D56's second,
which are nightly (ruling 47); their pass through `--typecheck-only` is `make check`'s for the 45 under a `LICENSE`
(`hs-rhc-corpus/vendored-SET`) and nightly for the 143 under a `PROVENANCE` (`hs-rhc-corpus/provenance-SET`; ruling 46).
`bin/rune-test hs-corpus-vendor` makes `vendored/` from the trees again, copying the programs' files and the `LICENSE`s
and leaving each `PROVENANCE` as written; `hs-corpus/data` holds `vendored/` to the vendored candidates' files and
notices and nothing more, refuses a file with no `LICENSE` or `PROVENANCE` beside it or above it, or under another
notice than its row's, and a `PROVENANCE` that does not name its tree's upstream and commit or quote the owner's rule;
and `hs-corpus/vendored` (nightly, with the trees) holds it to the trees' bytes. helium's GPL-3 programs are not of the
188 and stay outside. `examples/benchmarks/*/upstream/` holds nofib's originals for its ports, with `NOTICE` files of
their own; they are not this corpus.

The GHC shim of the oracles (`tests/hs/oracles/ghc-shim/`) holds three modules of GHC's libraries, `Random`,
`Locale` and `ShimTime` (from `random`, `old-locale` and `old-time`), under the BSD licence of GHC's `base`, which is
kept beside them as `BASE-LICENSE`; the rest of it is this project's.

## The files

| File | What it is |
|---|---|
| `trees.tsv` | each set's tree: its upstream, the commit E7 and E8 read (the commit `vendored/` is copied from too), and its licence file; a job refuses a tree at another commit |
| `licences.tsv` | the survey above, a row a candidate, with the notice of each vendored one |
| `candidates.tsv` | E8's 3,089 candidates: each one's main, the parent whose sources it includes, and what its suite expects of it |
| `accept.tsv`, `reject.tsv` | E8's judgements: each oracle's verdict in Haskell 98 mode, best over the variants, and GHC's `open`, Hugs's and GHC's `ext` where E8 asked them; what a candidate needs, and each oracle's first complaint |
| `run.tsv` | E8's run set: the 283 programs with an expected output, their inputs and the variant they run in, each oracle's build, exit status and output, and the CPU time and instructions under `ghc -O0` that D56 rests on |
| `conformance.tsv` | E7's 82 tests: what each suite expects, each oracle's verdict and first complaint, and E7's class of each disagreement |
| `vendored/` | the 188 programs of D56's set, 862 files, and their 8 notices (above): 45 programs under their trees' `LICENSE` files (GHC's testsuite's, jhc's), 143 with a `PROVENANCE` |
| `compat/` | E8's compat layer for the 2019 nofib: `NofibCompat.hs`, the names its harness takes from outside the Report; `NofibUtils.hs`, its `hash` over `Integer` and printing the 64-bit result (D22); and edits, by the path of the file they edit, of `spectral/hartel/Fast2haskell.hs` (the Report's modules, and bit operations by arithmetic) and of `spectral/sphere`'s own `hash` (over `Integer`, as D22 says) |

The data is E7's and E8's (the drafts' `results/E7/`, `results/E8/`), with each path made relative to the corpus's
directory and nothing else changed. The variants a candidate is judged in, and the compat layer's rewrite of its
imports, are those of E8, ported to SML in `tests/runner/hssource.sml` and `hscorpus.sml`; on the 6,071 sources of
the trees they give E8's results character for character. Fast2haskell's bit operations assume a 64-bit `Int` that
wraps, as nofib's did, which rhc's `Int` (63 bits, overflow an error, D22) does not give: they stand as E8 wrote them,
for the oracles, until rhc compiles them.

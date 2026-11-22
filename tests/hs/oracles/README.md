# rhc's oracles

The judges of D52: GHC 9.4.7 with the strict shim and Hugs `+98`, nhc98 `-98` third, MicroHs a smoke oracle. They
find disagreements, not truth: every expected result cites a clause, and where the judges disagree, or agree against
the clause, the disagreement yields a reading (`../readings.md` from R55, E9's before it), and rhc follows the Report
(D38). No oracle is in `make check`. The jobs `hs-oracles/*` are in the tier `nightly`, each needing its oracle's
capability and `hs-corpus` (`bin/rune-test doctor hs-oracles` says what is missing and how to get it), and a machine
without an oracle skips its jobs with that hint.

## What the jobs hold

With no rhc they reproduce the evidence the roadmap rests on, each outcome an oracle's on a program under a label:

| Label | What is asked | Held to |
|---|---|---|
| `conformance` | E7's 82 tests (`nhc98`'s `conformance98` and yhc's extras), each built and run as E7 did | what the test's suite expects: `ok`, `ok?` or `accept` where it expects a compile, `reject` where a failure |
| `judge` | each of E8's 3,089 candidates, accepted or not in some variant: as it stands with its pragmas blanked and the preprocessor run, with the import rewrite, and for the 2019 nofib with the compat layer | what E8 recorded (`../corpus/accept.tsv`, `reject.tsv`) |
| `open` | GHC with the Report's Prelude and every installed module in sight, where E8 asked it | E8's record |
| `ext` | Hugs `-98` and GHC's own language with the pragmas kept, where nothing else accepted | E8's record |
| `run` | the run set's 283 programs, built and run on their inputs: `BUILD/STATUS/OUTPUT`, output `same`, `same-ws`, `close` (numbers to about five digits) or `diff` | E8's record (`../corpus/run.tsv`) |

The same file holds the lines of rhc's own run programs (`hs/lang/...`, M19), which their runner judges on the
oracles; the checks here leave those to it.

An outcome that is not what it is held to is a failure, unless a line of `../oracles.txt` explains it, in the format
of `docs/testing.md` (*Expectations*): `ORACLE | PROGRAM::LABEL | CATEGORY | OUTCOME: why`. The reason begins with the
outcome it explains, so that an oracle whose verdict moves from one failure to another fails too. A line that explains
no failure of a job that ran is stale, and the oracle's `@stale` job fails on it, so a new build of an oracle cannot
change the evidence silently. Before it judges anything each job builds and runs hello on its oracle, and stops if
that does not print `hello`.

`make check` holds what needs neither oracles nor corpus (`hs-corpus/*`): the data is whole and agrees with itself
(3,089 candidates, each in `accept.tsv` or `reject.tsv` once, the 283 of the run set, D56's 188 the run set's programs
right in at most a second under `ghc -O0`); nothing is under `tests/hs/corpus/` but the data and the compat layer;
every disagreement E7 recorded has its line in `oracles.txt` naming its verdict, and no agreement has one; each of E7's
20 hard cases has a line citing a reading, but the two where nhc98 refuses legal code; the source rewrites do on planted
text what E8's did; and the harness fails, on fake oracles, where it must.

## The oracles

Each is found through a variable, as `RUNE_HS_CORPUS` finds the corpus (`../corpus/README.md`):

| Oracle | Variable | Pinned | How it is built |
|---|---|---|---|
| GHC 9.4.7 | `RUNE_HS_GHC`, `RUNE_HS_GHC_PKG` (`ghc` and `ghc-pkg` on `PATH` if unset) | 9.4.7, what Ubuntu 24.04's `ghc` is | installed; the shims below are built by the job `hs-oracles/@ghc-shim` in each run |
| Hugs | `RUNE_HS_HUGS`, its tree | github.com/augustss/Hugs `2719ab801574b2a177ea12014c69a8e694269162` (September 2006 sources) | unmodified: `./configure --prefix=$PWD/inst`, then `make all` in `src` and in `libraries`; run in place with `HUGSDIR=$RUNE_HS_HUGS/hugsdir` |
| nhc98 1.22 | `RUNE_HS_NHC98`, its tree | github.com/8l/nhc98 `b4d41520ae51f1db61ff6fb899775200e4cae731` | 32-bit from its `.hc` files, below |
| MicroHs | `RUNE_HS_MICROHS`, its tree | github.com/augustss/MicroHs `f17be7f0ebcbec94ad40121bea79ca3bf6c85d3f` | `make bin/mhs bin/cpphs bin/mhseval`; its job first writes a cache of its library and the shim, from a program that imports every module of the shim, and each test reads it (`-CR`), as E7's did |

**nhc98** builds under gcc 13 only 32-bit (gcc's multilib) and with chosen flags, found by trial (E7):

```text
sed -i -e 's/^ARCH = *$/ARCH = -m32/' -e 's/^OPT = -O3/OPT = -O1/' Makefile.inc
sh ./configure --buildwith=gcc --prefix=$PWD/inst --copts="-fno-strict-aliasing -fno-pie -fcommon -std=gnu89" \
   --ccoption="-m32 -fno-strict-aliasing -fno-pie -fcommon" --ldoption="-m32 -no-pie"
make basic-gcc GCCVERSION=13.2
```

`ARCH` is empty in `Makefile.inc` and the runtime casts labels to an unsigned 32-bit number, so it must be `-m32`.
`GCCVERSION` is parsed from `gcc --version`, which on Ubuntu's banner makes a shell test fail, so it is given. With
`-O3` and `-m32` alone its binaries crash in hmake's configuration; with `-O3` and no PIE they print
`PreludeList.init: empty list`; with `-O1`, `-m32` and PIE they crash; `-O1` with all of the flags above builds. Which
of `-O1` and `-fno-strict-aliasing` cures the wrong results was not separated.

## The shims

GHC 9.4 has no Haskell 98 mode of its libraries: the `haskell98` package died with GHC 7.8. So the GHC oracle runs
through two packages built from `ghc-shim/`:

- **`haskell98-shim`**, the strict one, exposes exactly the Report's module names, `Prelude` included, with
  `-hide-all-packages`, so that a hierarchical import is an error. Its `Prelude` is the Report's export list over
  GHC's; what it cannot shim is `Num`'s superclasses `Eq` and `Show`, `Monad`'s superclass `Applicative` and
  `Monad`'s `fail`, which GHC's classes carry.
- **`haskell98-compat`** puts the Report's library modules over GHC's own `Prelude` (`ghc-shim/compat/` holds the three
  that differ), for building what the strict shim refuses but GHC should simply run, and for E8's `ext`.

MicroHs has no Haskell 98 mode: `mhs-shim/` holds the Report's modules for it that differ from the GHC shim's, and
the rest are the GHC shim's. `Random.hs`, `Locale.hs` and `ShimTime.hs` are GHC's libraries' code (`random`,
`old-locale`, and `old-time` over `time`), under the BSD licence of GHC's `base`, which is `BASE-LICENSE` here; the rest
is this project's.

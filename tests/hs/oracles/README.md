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

## The 2010 oracles

The judges of rhc's Haskell 2010 mode (the haskell2010 roadmap's D39, M2), as E8 built and asked them: they find
disagreements, not truth, as the 98 ones do, and rhc follows the 2010 Report.

| Oracle | What it is | What it judges |
|---|---|---|
| `g10` | GHC 9.4.7 `-XHaskell2010 -XRebindableSyntax -XImplicitPrelude -hide-all-packages`, over the shim below and its defaulting plugin | acceptance and output, its limits stated |
| `gbase` | GHC 9.4.7 `-XHaskell2010` over base and 14 common packages | beside g10, to tell the language from the library |
| `gext` | GHC 9.4.7's default language with each file's own LANGUAGE pragmas and every installed package | the extension corpus, for track X |
| `mhs` | MicroHs, with its own library, the cache of `mhs2010-shim/` | acceptance only: it accepts much that 2010 refuses |
| `hugs`, `nhc98` | Hugs `+98`, nhc98 | further opinions on programs without 2010's changes (Hugs has no pattern guards, nhc98 no DoAndIfThenElse nor relaxed dependency analysis, both take n+k) |

They are the 98 oracles' binaries, found through the same variables (above), and GHC 9.4.7 is `RUNE_HS_GHC`. The
jobs are `hs-oracles2010/ORACLE/judge-SET`, `probes`, `run` and `@stale` (`tests/runner/hsoracles2010.sml`), in
the tier `nightly`, each needing its oracle's capability and its set's trees (`hs2010-corpus`, `hs-corpus`,
`hs-hackage`: `../../hs2010/corpus/README.md`). Before judging, each builds and runs hello on its oracle. With no
rhc they reproduce E8's evidence, each outcome under a label:

| Label | What is asked | Held to |
|---|---|---|
| `h10` | each candidate, after the filter, with its LANGUAGE, OPTIONS, INCLUDE and ANN pragmas blanked (the program must be 2010 without them), g10's copy importing `RebindableH2010` where its own Prelude import does not bring what RebindableSyntax reads: `accept`, `reject`, or `filtered` | E8's record (`judged.tsv`) |
| `h10ext` | gext on the same with its LANGUAGE pragmas kept and its suite's `-X` flags | E8's record |
| `h10probe` | the 23 probes of `../../hs2010/corpus/limits/`, built and run by g10 and gbase (`accept`, `output` where it prints other than the Report says, `reject`), checked by the others | the Report (`limits.tsv`) |
| `h10run` | the run tier's 90 programs built with `ghc -O0` over g10 or gbase as E8 built each, and run: `ok/STATUS/OUTPUT` or `fail` | E8's record (`run.tsv`) |

A difference is a line of `../oracles.txt` with the outcome first, as the 98 oracles' are, and `@stale` fails a line
that explains no failure of a job that ran. Every departure E8 recorded on a probe is such a line, so that a rebuilt
shim or oracle cannot move a limit silently: g10's eight limits, with L22, which agrees by reading (below); gbase's
ten and L22; Hugs's four, nhc98's five and MicroHs's five. `make check` holds the lines to the record
(`hs2010-corpus/data`: each names something with a record of its oracle under its label and an outcome other than
the one it is held to, and each recorded departure of a probe has its line).

### The shim: `ghc2010-shim/`

GHC's base is not the Report's library, so g10 compiles over two packages that the job `hs-oracles2010/@ghc2010-shim`
builds in each run, as E8's `build.sh` built them:

- **`haskell2010-report`** (`src/`): the Prelude and the Report's 30 modules, exactly their export lists (checked by
  E8 against T10's chapters 13 to 42), and `RebindableH2010`, the names RebindableSyntax looks up, for a program
  module whose own Prelude import does not bring them; hidden, `H2010.Classes` (the numeric and monadic classes),
  `H2010.Bits` and `H2010.Instances` (the classes' instances for base's other numeric types, written by E8's generator
  and kept by hand since). The numeric classes' code is the Report's, as rhc's haskell98 Prelude has it; Numeric,
  Data.Complex and Data.Ratio are 98's code over these classes; the rest delegates to base, each module's head saying
  which.
- **`h2010-default`** (`plugin/H2010Default.hs`): a defaulting plugin (GHC 9.4's `DefaultingPlugin`) that applies
  4.3.4's rule to the shim's classes, which GHC's own defaulting knows only by base's keys.

What it reproduces: Num with Eq and Show as superclasses; Monad with `fail` and no Applicative superclass; Functor,
Monad and MonadPlus with only the Report's instances; Bits under Num; the Prelude at list types, with no Applicative,
Semigroup, Monoid, Word or MonadFail names; the Report's `catch`, `try`, `splitAt` and `error`; 4.3.4's defaulting,
`default ()` included; the 2010 language's changes. **What it cannot** (E8's `oracles/README.md`; each but the last
measured by a probe):

1. Eq, Ord, Enum, Bounded, Show, Read and Ix are base's, since `deriving` names only base's: derived Show
   parenthesises a record argument (L04), and `read "0x10" :: Int` parses (L05).
2. Ratio is base's, since GHC types a fractional literal at base's Rational even under RebindableSyntax: Ord of
   `Ratio a` for a type variable `a` is refused (L01).
3. RebindableSyntax reads literals, negation, `do` and `if` through the names in scope: the Prelude exports one name
   more, `ifThenElse`, and a program that defines its own, or hides and redefines `>>=`, `negate` or the like, is
   misjudged (L02, L03, L23).
4. GHC's own departures from the Report (its `bugs.rst`): a prefix `!` read as a bang pattern (L06), duplicate array
   indices unchecked (L15), and the rest that file lists.
5. Int is 64 bits and wraps; Char is Unicode as base 4.17 has it; I/O encodings are the locale's.
6. **The ninth limit, which no probe covers:** Foreign.C.Types exports the arithmetic C types with their newtype
   constructors, and Foreign.Ptr `IntPtr` and `WordPtr` with theirs, where the Report exports them abstractly, since
   GHC marshals a newtype in a foreign declaration only with its constructor in scope (L16 was refused until E8 made
   this change). So a program that writes `CInt 3` is wrongly accepted.

Measured on the probes: g10 agrees with the Report on 14, departs on 8 (L01 to L06, L15, L23), and on L22
(`realToFrac` of a NaN) prints `-Infinity`, which agrees by reading: the Report's `realToFrac = fromRational .
toRational` makes of a NaN what `toRational` makes of it, and that is not NaN (W8). GHC 9.4.7 accepts `forall` as a
term variable (L07), which 9.14.1 no longer does.

MicroHs has no array package: `mhs2010-shim/Data/Array.hs` is `mhs-shim/Array.hs` under its 2010 name, and the job
`hs-oracles2010/@mhs2010-cache` writes the cache every MicroHs job reads, from a program that imports every module
of the Report.

The shim's code is the Report's (its numeric classes and the modules of 98's code), base's (the definitions of 2010's
added names, Foreign.C.Error's and Foreign.Marshal's functions over the shim's classes) and E8's own, all of it under
`BASE-LICENSE`, base's licence, which carries the Haskell 98 Report's notice and the FFI Addendum's beside the
University of Glasgow's.

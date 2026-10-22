# Units: making a compile in units cost what a whole compile costs

## Status

Not started. Recorded 2026-10-20 at the owner's request, from what
[performance.md](performance.md)'s M10 measured at `a6a024ab1`. The
numbers and the profile are in
[incremental-compilation.md](incremental-compilation.md), *After M12: what
is left*, under "MLton's compiler in units costs five times its whole
compile"; this file turns them into fixes.

## Where we are

MLton's compiler (606 files) compiled by Rune at tier 2:

| | Whole | Units (`--units --no-cache`) |
|---|---:|---:|
| Processor time | 84 s | 433 s |
| Elaboration | 71 s | 56 s |
| `unit-usages` | | 174 s |
| `unit-export` | | 148 s |
| `unit-load` | | 29 s |
| `link` | | 15 s |

Everything else in the units build (parsing, the middle end, the back
end) is about 10 s. The units' interfaces cost four times the compile
itself. MLton's build of the same compiler shows the same shape: 263 s in
units, 98 s of it usages and 110 s export, against 60 s whole.

**What the time is.** `perf record` of the units build at tier 2:

* `P.hash`'s loop (`src/util/pickle.sml`) is 36% of the cycles;
* the collector 25%, much of it the garbage of the text being hashed;
* string concatenation and its copies 8%;
* building the fingerprints' text (`fpEnv`, `fpTy`, `fpFunctor`) 1.3%.

The build hashes 2,136 MB, counted by call site in a build with counters:

| What is hashed | MB | Hashes |
|---|---:|---:|
| A signature's fingerprint in the usages (`fpSigma`) | 818 | 710 |
| A functor's fingerprint in the usages (`fpFunctor`) | 430 | 260 |
| The same functors' fingerprints again in `export` (`binding`) | 432 | 280 |
| The basis's pickle, for the unit's identity, in `export` | 220 | |
| The same pickle again in `load` | 220 | |
| Everything else | 27 | |

One unit, `codegen/amd64-codegen/amd64-codegen.fun`, hashes 190 MB: 12
functor fingerprints of 7.3 MB of text each, twice. A byte costs about
170 cycles at tier 2: four `mod`s by constants a character, which tier 2
compiles to `idiv`.

**Why the text is so long.** A fingerprint is the hash of a text that
spells out what a name names ([units.md](../units.md), *Fingerprints*):
for a structure every entry, every value's type written out in full; for
a signature its whole environment; for a functor, since performance M3,
its signature: the parameter and the result. MLton's code generators take
and return structures with hundreds of components, so the text of one
functor runs to megabytes.

**What M3 changed.** On MLton's build, at `921af2cc`, a compile in units
took 281 s: elaboration 139 s, usages 55 s, export 55 s. At the tip:
263 s, with 20 s, 98 s and 110 s. Typing functors by their signature took
119 s out of elaboration and put 98 s into the interfaces.

**Ruled out:**

* `fpTy`'s list of type variables, which is quadratic: 0.8% of the
  cycles.
* The memo of fingerprints lost between units: one process compiles every
  unit, and `startSession` empties `fpMemo` once. It hits 61,550 times
  and misses 23,096. What goes around it is `export`'s `binding`, below.
* Pickling itself: about 1.4%.

## The fixes

In the order to build them: the first two are small and change no output.

### F1. `export`'s functor fingerprints through the memo

`export`'s `binding` (`src/driver/unitbasis.sml`) asks `fingerprint k` for
a `"fun "` key, not `fingerprintAt (k, binder)`, so the 260 functor
signatures the usages hashed are hashed again: 432 MB.

* **Change:** ask `fingerprintAt` with the key's binder. Check that the
  binder is the one `usageValue` uses for the same key, so that the memo
  holds the same text.
* **Gain:** −432 MB hashed, about 20% of the hashing and its garbage.
* **Output:** none changes. The unit files must be byte for byte the same.

### F2. The identity from `export` given to `load`

`export` hashes the basis's pickle for the unit's identity, and `load`
hashes the same bytes again (`identity = uname ^ "@" ^ P.hash hashed`):
220 MB twice.

* **Change:** `load` takes the identity that `export` worked out when it
  is called on the pickle just made. It still works the identity out
  where it reads a unit from the cache, where the pickle comes from a
  file.
* **Gain:** −220 MB hashed.
* **Output:** none changes.

### F3. Fingerprints as hashes of hashes

The fix for the text itself. A structure's or a signature's fingerprint
becomes the hash of its entries' names and their fingerprints, not of
their text; a functor's, the hash of its parameter's and its result's
fingerprints. Each is worked out once and kept by a key for what it is
the fingerprint of, so that no text is longer than one entry's.

* **What must not change:** what a fingerprint decides. Two names have
  the same fingerprint where their texts would have been the same. A
  change under a name still changes every fingerprint that names it, and
  a change beside it none. The cut-off scenarios of
  `tests/incremental/SCENARIOS.md` (S65 to S67 for functors among them)
  are the test.
* **What changes:** every fingerprint's value, so the unit files and the
  cache. The version keys of both are bumped, so that an old cache is a
  miss.
* **Gain:** the rest of the 1.25 GB of signature and functor text, most
  of the collector's 25% and the concatenation's 8%. The aim is
  `unit-usages` and `unit-export` together under 30 s on MLton's compiler.
* **Risk:** a keyed memo needs a key that is stable across the units of a
  session. A structure or a signature has no stamp of its own today
  (`Env.Env` is its entries, `SigMatch.sigma` its bound names and its
  environment), so the key may have to be its binder and path, as a
  usage's key is.

### F4. A hash that costs less a byte

`P.hash` keeps four 24-bit hashes, each `(h * k + c) mod p` with a prime
`p` below 2^24, so that a host with 31-bit integers works it out like any
other.

* **Either** tier 2 compiles division by a constant as a multiplication
  and shifts ([jit.md](jit.md), *Left by the performance plan*, "Division
  by a constant"). That changes no hash and helps every `mod` by a
  constant, `IntTable`'s too.
* **Or** a hash with masks instead of `mod`s, `(h * k + c) land 0xffffff`,
  or a word-sized hash done in `Word` on every host. That changes every
  hash, so it bumps the version keys as F3 does. It must give the same
  value on the 31-bit hosts (SML/NJ's `smlnj32`), which `check-cross`
  holds. Its collision behaviour must be argued before it replaces the
  four primes: identities are content hashes the cache trusts.
* **Gain:** about 170 cycles a byte now. After F1 to F3 little text is
  left, so F4 matters less the more of F3 is done. Take the first option
  where the JIT's work is planned anyway.

## Measure of done

* MLton's compiler compiled in units at tier 2 (`--units --no-cache`)
  within 1.5 times its whole compile, from 5.2 times today.
* Hashing under 5% of that build's cycles.
* F1 and F2: unit files byte for byte the same as before.
* F3 and F4: the incremental scenarios unchanged in what they compile
  again and what they load from the cache; `make check`; `check-cross`.

## Measuring

* `scripts/setup-mlton.sh DIR` once, then, in `DIR/mlton`, the units
  build: `bin/runevm --stats bin/rune.rbc --lib lib --units --no-cache
  --pass-stats -o OUT $(cat mlton-rune.txt)` with the tree's paths, and
  `bin/rune-mlton` in place of `bin/runevm bin/rune.rbc` for MLton's build.
  `--pass-stats` gives `unit-usages`, `unit-export` and `unit-load` for
  each unit. The whole compile to compare with is
  `bin/rune-measure perf-units --mlton DIR --configs tier2,mlton phases`.
* The bytes hashed by call site: a build with a counter in `P.hash`, per
  caller. Counts are the same on every engine, so MLton's build gives them
  in a few minutes.
* Where the cycles go: `perf record` over `--jit-perf-map`, with
  `bin/rune-measure perf-groups`.

## Where the evidence is

With the drafts of performance.md (`~/.cache/claude-rune-drafts/performance`
on the machine they were made on): `results/M10/units/` (the profile at
tier 2, the units builds on MLton's build at `921af2cc` and at the tip,
and `exp/`, the counts by call site) and `results/M10/e5/` (the whole and
units compiles at tier 2).

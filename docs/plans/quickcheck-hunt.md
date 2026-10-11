# The hunt: the laws of the Basis Library, run (quickcheck M9)

This is the record that *The blind test* of `docs/plans/quickcheck.md` asks
for. It covers the runs, every failure with its class, its shrunk
counterexample and its replay token, and what each failure was found to be:
the law wrong, the implementation wrong, or both, or the tester. It is
written as the hunt goes, and the owner says at its end which law they meant.

The protocol, fixed before the hunt began:

1. Run every law at every implementation with the settings of `make check`,
   then in the deep mode (P11). The seeds are 1 to 1,000.
2. Record every failure: its class, its shrunk counterexample and its replay
   token.
3. Classify each failure: the law is wrong, the implementation is wrong, or
   both. D10's runs against the other compilers help decide which.
4. Restate or fix, and run again. The hunt is repeated until a full run
   reports nothing new. A change of a law's meaning is the owner's: it goes
   into the table below for them, with the counterexample kept as a
   `Counterexample:`.
5. The owner says which law was meant.

## Before the hunt

What was changed in the tester before the first run of the hunt, and why, is
in `docs/plans/quickcheck.md`, M9, *Before the hunt*. In short:
- functions are no longer compared as values;
- counterexamples and named laws were added;
- P14 draws an integer variable within the bounds its conditions set.

## The adequacy of the laws: mutants of the Basis Library

Brought forward from the end of the hunt, to learn how much a law's pass is
worth before relying on one (2026-09-28).

**How it was run.**
- `tests/basis/run-mutants.sh` takes 14 files of `lib/basis` and the structure whose laws hold each.
- `tools/mutate/mutate.sml` changes one token of a file's code at a time: a comparison into its neighbour, `+` and `-` into each other, `andalso` and `orelse`, `true` and `false`, 0 and 1, or the exception a `raise` names.
- At most 20 sites of each file are tried, evenly spaced, and each mutant is run against the laws at its structure.
- A mutant is killed when a law that passes on the Basis Library does not pass on it. *Stillborn* means it did not compile.

**Results.** Run with P14 and the edges of P1 as they are now:

| File | Result |
|---|---|
| `list` | 13 of 17 mutants killed, 4 survived, 0 stillborn |
| `listpair` | 5 of 7 mutants killed, 2 survived, 0 stillborn |
| `char` | 7 of 18 mutants killed, 11 survived, 0 stillborn |
| `string` | 3 of 15 mutants killed, 12 survived, 2 stillborn |
| `substring` | 3 of 20 mutants killed, 17 survived, 0 stillborn |
| `int` | 4 of 16 mutants killed, 12 survived, 2 stillborn |
| `intn_fn` | 7 of 7 mutants killed, 0 survived, 6 stillborn |
| `intinf` | 9 of 17 mutants killed, 8 survived, 2 stillborn |
| `word` | 6 of 13 mutants killed, 7 survived, 3 stillborn |
| `wordn_fn` | 4 of 12 mutants killed, 8 survived, 6 stillborn |
| `array` | 7 of 19 mutants killed, 12 survived, 0 stillborn |
| `arrayslice` | 6 of 20 mutants killed, 14 survived, 0 stillborn |
| `array2` | 7 of 20 mutants killed, 13 survived, 0 stillborn |
| `byte` | 5 of 8 mutants killed, 3 survived, 0 stillborn |

In all, 86 of the 209 mutants that compiled were killed and 123 survived.
The survivors are mostly where no law is:

| Where the mutant is | Killed | Survived |
|---|---:|---:|
| A member with a law that passes | 22 | 8 |
| A member without one | 64 | 115 |

Where a law exists, it kills 73% of the mutants. Its 8 survivors are the laws', not the tester's:
- **5 are cases the law's condition leaves out** (`ArraySlice.update` and `Byte.packString` out of range, and `Char.succ maxChar`). The mutant changes only the exception raised there.
- **1 is equivalent:** `Int.min` with `<=` for `<` gives the same value.
- **2 are laws that relate members but pin no value.** `isPrint` made true of every character still has `isPrint c = (isGraph c orelse c = #" ")`, because `isGraph` is `isPrint` without the blank. And `sign 0 = ~1` still has `fromInt (sign i) * abs i = i`.

The mutants of members without a law that survived are the documentation's
gaps, not the tester's. `ListPair.allEq` has no law, for one. Where another
member's law uses a member without one, that law kills its mutants: 64 of
the 179 mutants there.

**What the first mutation run found in the tester**, both fixed before these numbers:
- **The edges of P1 and P3.** A mutant of `Word.fromLargeInt` that is wrong only at the top bit survived 100 cases, because the top bit was one of about 200 edges. The extremes are now drawn half the time (*Generator principles*, P1), and the mutant is killed.
- **The driver.** A mutant of `List.tabulate` that loops hung the tester itself, which uses the Basis Library, before any law ran, and was counted as surviving. A mutant is now killed when a law that passes on the Basis Library does not pass on it, for whatever reason.

## The owner's rules for the hunt (2026-09-28)

The owner took these, each as recommended:

- **Documented exceptions.** A law that fails only on a case its own member documents under `Raises:` is restated with the condition that excludes that case, and keeps the case as a `Counterexample:`. The documented cases are `Size` past `maxLen`, `Subscript` out of range, `Div` by zero, `Date` for a date that cannot be represented, and a NaN or an infinity where a real law meets one. Every such restatement goes into the table of restatements, which the owner may veto row by row.
- **`Substring.splitl`** holds only when its predicate has no effects, and says so.
- **`Math.atan2`**'s law holds for finite reals, and says so. (Superseded after run 2: it fails for finite reals too, and is on the skip list; *The owner's decisions*.)
- **The Posix conversions of words** hold for words within the range of `int`: a condition, and not a change to Rune.
- **`INetSock.toAddr` and `INet6Sock.toAddr`** keep accepting any port. Their laws hold for ports from 0 to 65535, as a condition.
- **`Date`:** Rune's note that any year that is an `int` has its dates is corrected, and the year of M7's translation of "fields in range" is bounded.
- **Domains** (D7) are named where random values never meet a law's condition. `OS.Path.mkRelative`'s law draws canonical absolute paths, and the laws of `IntInf.<<` and `IntInf.pow` draw exponents below 4096.
- **Laws written for `char`** that do not elaborate at `WideString` and `WideSubstring` are rewritten generically, where that is notation only. (None is: *The owner's decisions*.)

## Run 1 (2026-09-28)

Every law at every structure, with the settings of `make check`: 1,733 laws
at their structures, after P14.

| Result | Laws |
|---|---:|
| pass | 1,439 |
| fail | 191, of which 23 gave up |
| stopped | 103 |

**What it showed of the tester.** The stopped laws are those of `array` and
`tabulate` at the arrays and vectors, and of `IntInf`. A length drawn over
the whole range made an array of millions of elements, and the machine ran
out of memory. Before the next run the tester got a work budget, the skipping
of a case the machine cannot hold, and a runner that runs the structures in
parallel under a memory bound (commit "Prepare the hunt").

## Run 2 (2026-09-28)

The same laws with the budget and the skipping.

| Result | Laws |
|---|---:|
| pass | 1,440 |
| fail | 291, of which 23 gave up |
| stopped | 2 |
| cases skipped, the machine could not hold them | 97 |

The failures, grouped by what they were. A law at 19 structures is one row.

| Law | Shrunk case | What it was | What was done |
|---|---|---|---|
| `array`, `tabulate` at `Array`, `MONO_ARRAY`, `MONO_VECTOR`, `Array2`, `MONO_ARRAY2` | a length past `maxLen`, as `(100098463, fn, 0)` | the law: `Size`, documented | restated |
| `copy` at `Array` and `MONO_ARRAY`, `Array.copyVec` | `(fromList [false], (fromList [], 0, 0))` | the law: `Subscript`, documented | restated |
| `sub` and `subslice` of the slices | a start of `~1` | the law: `Subscript`, documented | restated |
| `MONO_VECTOR.update`, both laws | `(fromList [], 0, false)` | the law: `Subscript`, documented | restated |
| `PackReal.update`, `PackWord.update` | `(fromList [], 0, 0)` | the law: `Subscript`, documented | restated |
| `Substring.base` | `("", 0, ~1)` | the law: `Subscript`, documented | restated |
| `INTEGER.mod`, `INTEGER.rem`, `WORD.mod` | `(0, 0)` | the law: `Div`, documented | restated |
| `Real.split` | a NaN | the law: a NaN | restated |
| `Math.atan2` | `(~inf, inf)` at `Math`; `(9.97E~257, 1.14E~255)` at `Real.Math`, and one at `Real32.Math` | the law: infinities, and rounding (below) | for the owner |
| `Substring.splitl` | `p` is applied once to the character, and twice by the pair | the law: an effect | restated |
| `Date.year`, all six | the year ~25252734927764585 at an offset | the law: `Date`, documented; and a bug of Rune (below) | restated, and fixed |
| `INetSock.toAddr`, `INet6Sock.fromAddr` | the port `~1`, which comes back as 65535 | the law | restated |
| the Posix conversions of words, six | `0wx8000000000000000` | the law: `Overflow` beyond `int` | restated |
| `IntInf.~>>` | `(0, 0wx81EA301809906281)`: the right side's `Word.toInt n` overflows | the law, for a shift no machine can do | a domain |
| `IntInf.<<`, `IntInf.pow` | stopped: the stack, and a minute for a case | resources | a domain |
| `OS.IO.pollToIODesc`, both; `Posix.FileSys.iodToFD` | two pipes compared | the tester: each side drew its own pipe | `Gen.shared` |
| `OS.IO.hash` | gave up | the tester: `x = y` is rarely met | P14 draws `y` as `x` |
| `ArraySlice.slice`, `MONO_VECTOR_SLICE.length` | gave up | the tester: "when the slice exists" is rarely met | the same condition in bounds form |
| `OS.Path.mkRelative` | gave up | the tester: canonical absolute paths are rare | a domain |
| `ListPair.unzip` | gave up | the tester: two lists of one length are rare | for the owner |
| `STRING.compare`, `toString`, `fromString`; `SUBSTRING.compare` at `WideString` and `WideSubstring` | no Standard ML there | the law names `Char` or `String` | for the owner |

**A bug of Rune: local dates past C's `int`.** `Date.date` gives a local
date (`offset = NONE`) to the C library with the year less 1900 as a C `int`
of 32 bits, and a year that does not fit was read as another. The year
3000000000 came back as ~1294967296, and 2147485548 as ~2147481748. `fmt`
checked the year and `date` did not. Now `date` raises `Date` for a local date
with a field or a year that C's `int` cannot hold, as its `Raises:` says for a
date that cannot be represented; the check is
`Date.date/local-Date-or-the-year-past-an-int-of-C`. The law did not find it:
its shrinking went to the other failure, the offset's `Date`, which the
documentation allows. The probe for the restatement did.

### The restatements

By the owner's rules. Each keeps the case that broke it as a
`Counterexample:`, which the examples' programs try. The owner may veto any
row.

| Law | Condition added | Counterexample |
|---|---|---|
| `sub (array (n, x), i) = x` (`Array`, `MONO_ARRAY`) | `n <= maxLen`; run for `n` up to 2^20 | `sub (array (maxLen + 1, 0), 0) = 0` |
| `sub (tabulate (n, f), i) = f i` (`Array`, `MONO_ARRAY`, `MONO_VECTOR`) | `n <= maxLen`; run for `n` up to 2^16 | `sub (tabulate (maxLen + 1, fn i => i), 0) = 0` |
| `array` and `tabulate` of `Array2` and `MONO_ARRAY2` | `r <= Array.maxLen div c`; run for `r` and `c` up to 1024, and 256 for `tabulate` | `sub (array (Array.maxLen, 2, 0), 0, 0) = 0` |
| `copy` (`Array`, `MONO_ARRAY`), `copyVec` | `0 <= di andalso di <= length dst - length src` | a source of two into an array of one |
| `sub` of `ArraySlice`; `subslice` of the three slices | `0 <= i andalso i < length sl` (the slice's or the array's) | a start of `~1` |
| `MONO_VECTOR.update`, both | `0 <= i andalso i < length v` | `sub (update ("abc", 3, #"x"), 3) = #"x"` |
| `PackReal.update`, `PackWord.update` | `0 <= i andalso i < Word8Array.length arr div bytesPerElem` | an array too short for the element |
| `Substring.base` | `0 <= i andalso i <= size (full s) andalso 0 <= n andalso n <= size (full s) - i` | `base (substring ("", 0, ~1)) = ("", 0, ~1)` |
| `INTEGER.mod` | stated in `LargeInt`, with `j <> 0 andalso (j <> ~1 orelse minInt <> SOME i)` (the named law: run 3) | `1` by `0`; `valOf minInt` by `~1`; and `valOf maxInt` by `~2`, whose product overflows |
| `INTEGER.rem` | `j <> 0 andalso (j <> ~1 orelse minInt <> SOME i)` | `1` by `0`, and `valOf minInt` by `~1` |
| `WORD.mod` | `b <> 0w0` | `0w1` by `0w0` |
| `Real.split` | `not (isNan x)` | the NaN |
| `Substring.splitl` | when `p` has no effects | the count of `p`'s calls |
| `Date.year` and the five others | the year from ~10^9 to 10^9; run for `r` from `DateArb.fieldsInRange` | the year `valOf Int.maxInt` at an offset |
| `INetSock.toAddr`, `INet6Sock.fromAddr` | `0 <= port andalso port <= 65535` | the port `~1` |
| the Posix conversions of words, six | `SysWord.<= (w, SysWord.fromInt (valOf Int.maxInt))` | `0wx8000000000000000` |

Rows that go past the rules, or where the rules were applied with a choice:
- **`INTEGER.mod` and `INTEGER.rem`** exclude `(minInt, ~1)` as well as a zero divisor. There `div` and `quot` raise `Overflow`, which their own `Raises:` documents; the laws' members, `mod` and `rem`, do not raise.
- **The Date laws' year** is bounded at 10^9 either way, a bound every C `int` holds. The year is a field of the law's record `r` and not a variable, so P14 cannot draw into a tighter bound: the specification's 1900 to 2200 would give up.
- **Lengths the tester can hold** (after run 3). The laws of `array` and `tabulate` are run for lengths up to 2^20 and 2^16, and those of `Array2` for up to 1024 rows and columns, and 256 for `tabulate`. Their conditions and counterexamples still speak of `maxLen`. A length drawn up to `maxLen`, 10^8, cannot be tried under the runner's 4 GB: an element takes 16 bytes, so an array of 6 * 10^7 elements is the most that fits, and a `tabulate` past about 3 * 10^5 goes past the work budget of a million calls and is discarded. Run 3 spent up to half an hour at each structure on such cases.
- **The Date laws draw from a domain**, `DateArb.fieldsInRange`: every field in its range, the year from ~10^9 to 10^9. With the year bounded, the fields of `DateArb.fields` were all in range too seldom, and run 3 gave up on all six laws.
- **`IntInf.pow`'s domain** is exponents below 16, not 4096. `pow (i, 8190)` of a 3000-bit `i`, which the generator makes, did not finish in five minutes; at 1022 it takes a second. `<<` and `~>>` draw shifts below 4096, as approved.
- **`ArraySlice.slice` and `MONO_VECTOR_SLICE.length`** have their condition "when the slice exists" in bounds form. It is the same condition; the slice's `Raises:` gives the bounds.
- **Rune's Date note** (`Date.date/any-year`) now says what holds: a date at an offset for a year whose days from 1970 are an `int`, up to about 25 * 10^15 either way at 64 bits, and a local date for fields that C's `int` holds.

### The owner's decisions (2026-09-28, after run 2)

- **A skip list** for what cannot be fixed (D12 changed): `tests/basis/law-skips.txt`, `label-glob | FAILS or UNTESTED | why`. `runedoc --law-skips` marks each listed law on its page beneath it, "Does not hold in Rune" or "Not tested in Rune", with the structures and the reason, and `make test-laws` counts its failure as known and its pass as a line to remove.
- **`Math.atan2`** is on the list as `FAILS`, and its comment says why. It is not a fault of Rune's: at both failing cases `atan2` is the correctly rounded value (checked with mpmath at 300 bits), and `atan (y / x)` is off by one place, because `y / x` is rounded first. At `Real.Math`, `(9.9740199574360859E~257, 1.1351872380907991E~255)` gives `0.08763728197467506` from `atan2`, correctly rounded, and `0.08763728197467505` from `atan (y / x)`. The case is the law's `Counterexample:`.
- **`ListPair.unzip`** has both laws: `unzip (zip (l, m)) = (l, m)` when `length l = length m`, on the list as `UNTESTED` because the tester gives up on it, and `zip (unzip l) = l`, which is tested.
- **For general solutions later**, and no quick workaround now: the three below are noted in `docs/plans/quickcheck.md`, *Later*, with the general form each needs (companion structures, laws of the reals in floating point, variables drawn together).
- **The laws for `char` at the wide structures** are on the list as `UNTESTED` at `WideString` and `WideSubstring`, where they are no Standard ML. `STRING` and `SUBSTRING` name no structure of their characters, so a law that needs one names `Char` or `String`. A generic law that says less, `compare (s, t) = collate (fn (c, d) => compare (str c, str d)) (s, t)`, would hold at both.

## Run 3 (2026-09-28, stopped at 39 of 174)

With the restatements of run 2. It was stopped after 39 of the 174 runs of
a program at a structure, when all it could still find was known, and its
runs of `MONO_ARRAY` took up to half an hour at each structure.

| Result | Laws |
|---|---:|
| pass | 457 |
| fail | 17, of which 7 gave up |
| stopped | 16 |

- **The named law** (`docs/plans/quickcheck.md`, *The named law*). With `Div` and `(minInt, ~1)` conditions of the law, `(i div j) * j + (i mod j) = i` raised `Overflow` at all seven structures of fixed width: `(1, ~128)` at `Int8`, found by the exhaustive search at case 768; `(~9223372036854775807, 3)` at `Int`; `(2057876007, ~126323960)` at `Int32`. It is restated in `LargeInt`, as the roadmap recommended and the owner took, and holds at all nine structures, at `Int8` over all 65,279 pairs the condition admits.
- **`Math.atan2`** and **`ListPair.unzip`**, as in run 2: now on the list.
- **The Date laws** gave up: the bounded year, among the other fields, was met too seldom. They now draw from a domain.
- **The laws of `array`** stopped at 16 structures: the machine could not hold the lengths drawn. They now run for lengths it can hold. The runner no longer stops a law after ten cases that run out of memory at once, only after ten that the watchdog stops, or fifty in all.

## Run 4 (2026-09-28)

With everything above: the restatements, the domains, the named law in
`LargeInt`, and the list of laws that do not hold or are not tested. 17
minutes at four jobs, 50 of CPU.

| Result | Laws |
|---|---:|
| pass | 1,726 |
| fail | 8, every one on the list |
| stopped | 0 |
| cases skipped | 0 |
| laws on the list that pass | 0 |

**Nothing new**, so the hunt's runs at the settings of `make check` end
here (the protocol's step 4). Two things for later:
- **Weak passes.** The laws of `Array2.fromList` and `MONO_ARRAY2.fromList` pass their 100 cases after 700 to 933 discards, near the 1,000 at which the tester gives up. Their condition holds only when the rows are all of one length, which random lists seldom are: the weakness that `ListPair.unzip` is listed for. A tester that draws lists of one length where a law needs them would serve all of them.
- **Time.** The structures of `LargeInt` elements are the slowest, about eight minutes each for `MONO_ARRAY`, `MONO_VECTOR` and `MONO_ARRAY2`, most of it in `tabulate`. It matters when `make test-laws` joins `make check`.

What remains of the protocol: the deep mode (P11), the runs against the
other compilers (D10), and the owner naming the law they meant.

## A week's pause, and a new implementation (2026-10-09)

The branch was rebased onto master after the heap-layout and collector
roadmaps had merged. Rune's implementation changed under the laws:
- `int` and `word` have 63 bits, a word of the machine less the bit that tells a number from a pointer, and so does `SysWord`; `Int64` and `Word64` are types of their own;
- a new collector, with a nursery and two old spaces;
- the compiler makes the register bytecode, which the register VM runs with its JIT.

What the rebase changed in the hunt's work, each in the commit that made
it:
- six counterexamples of the Posix conversions named `0wx8000000000000000`, which no longer fits a `SysWord`; they now name the word one past `maxInt`, whatever the widths, and it still raises `Overflow`;
- Rune's Date note: a date at an offset now reaches about 12.6 * 10^15 either way, and `toTime` raises `Date` from about the year 148000, not 292000 (the latter was stale since the 63-bit `int`);
- the hash of the frozen generators, `2DFFB655CD4806DC`: the edges of P1 with `Int64` as a type of its own.

**The register VM with its JIT is the default** (the owner, 2026-10-09):
the laws run on it, and the stack VM is what they are compared with.

## Run 5 (2026-10-09)

On the register VM with its JIT, at eight jobs: 8 minutes, 32 of CPU.

| Result | Laws |
|---|---:|
| pass | 1,726 |
| fail | 8, every one on the list |
| stopped | 0 |
| cases skipped | 0 |
| laws on the list that pass | 0 |

The same as run 4, on the old implementation: nothing new.

**Compared with the stack VM.** The same run on the stack VM
(`RUNE=bin/rune-stack RUNEVM=bin/runevm-stack`), 27 minutes and 116 of
CPU, gives the same result for every law. With the seeds fixed, 171 of the
174 outputs of a program at a structure are the same to the byte. The other
three differ only by four cases of `tabulate`, at `LargeIntArray`,
`Int64Vector` and `LargeIntVector`, that ran past the watchdog's minute on
the stack VM and were skipped, which the register VM finished. The two VMs
agree on every law, every case drawn and every counterexample.

## The deep run (2026-10-09)

Seed 1, 10,000 cases for each law at each structure (`RUNE_PROPERTY_DEEP=1
RUNE_PROPERTY_SEEDS=1`; P11 as the owner chose), on the register VM with
its JIT, at eight jobs.

| Result | Laws |
|---|---:|
| pass | 1,725 |
| fail | 9: the 8 on the list, and `OS.Path.splitDirFile` (below) |
| stopped | 0 |
| cases skipped | 7, each a case of `tabulate` with `LargeInt` or `Int64` elements that ran past the watchdog's minute |
| laws on the list that pass | 0 |

It took 16 hours, 60 of CPU. The listed laws failed as before, and more
plainly: `Math.atan2`'s law at ordinary values (`0.67474094222355263`
against `0.67474094222355274` at case 702), and `ListPair.unzip`'s gave up
after 5,753 cases and 100,000 discards.

**The runner's weakness.** After a skipped case, `run-laws.sh` starts the
law again from its first case, so a law with three skips near its end ran
most of its 10,000 cases four times: `MONO_ARRAY` at `LargeIntArray` took
15.6 hours, half the run. The cases are fixed by the seed and their index,
so the runner could go on at the case after the skipped one. For later.

**Found: the law of `OS.Path.splitDirFile`.** `joinDirFile (splitDirFile
p) = p` for `p <> ""` failed at case 10,359, shrunk to `p = "//"`:
`splitDirFile "//"` is `{dir = "/", file = ""}`, which joins to `"/"`. A
path loses every empty arc before its last: `"a//b"` comes back as `"a/b"`,
and `"///"` as `"//"`. The root with one empty arc reads as the root alone.
The law is wrong and the implementation right: MLton, SML/NJ 110.99.9,
Poly/ML 5.9.2 and MLKit 4.7.23 all give what Rune gives (D10, for this
case). The regular runs missed it, because a random string seldom has two
separators together.

The owner took the restatement proposed: the law holds for paths with no
empty arc before the last, and `"//"` is its `Counterexample:`:

```
Law: `joinDirFile (splitDirFile p) = p` for `p <> ""` when `let val arcs =
#arcs (fromString p) in List.all (fn a => a <> "") (List.take (arcs,
length arcs - 1)) end`
```

It passes 100 cases at the settings of `make check` and 10,000 in the deep
mode.

**Why the regular runs missed it, and what changed** (the owner took both
changes, 2026-10-09, while the deep run went on). A character was `/` once
in 512 draws (P5), so two together almost never; SmallCheck's characters,
the first letters, would have missed it too, and so did the small scope
(P13), whose characters are the three simplest codes. Now:
- `/` is among P5's characters with a meaning, beside those of SML's syntax;
- the laws of `OS.Path` draw from `BasisDataArb.path`, paths built from arcs: empty, `.`, `..`, names, names with an extension and any string.

With the domain, the old law fails at case 32 of a regular run, in the
small scope, already shrunk to `"//"`. The six laws of `OS.Path` pass, at
the regular settings and in the deep mode. The generators' hashes are
renewed: the fingerprint `CFA1F44CE9D34AAC`, the frozen `AC19EEA9CFFFB60D`.
The deep run's programs were compiled before the change, so the laws that
draw characters are run again after it:
- **Run 6**, every law at the settings of `make check` with the new generators: 1,734 laws at their structures, 1,726 pass, the 8 failures the listed ones. The same as run 5.
- **The deep mode again**, for the 17 programs whose laws draw characters, strings or paths, at all their structures, and for those of `MONO_VECTOR`, `MONO_ARRAY`, their slices and `MONO_ARRAY2` at the structures of characters (`LAWS_AT`, which `run-laws.sh` now takes): 548 laws at their structures, 544 pass, the 4 failures the listed laws for `char` at the wide structures. The restated law of `OS.Path.splitDirFile` holds.

So the deep mode, with the generators as they are now, finds nothing more.

## The other compilers (D10, 2026-10-10)

`tests/basis/run-laws-hosts.py` (`make test-laws-hosts`) builds the
programs of `runedoc --laws` with MLton, SML/NJ 110.99.9 (64 and 32 bits),
SML/NJ 2026.2, Poly/ML and MLKit, against their own Basis Library, and runs
them with the settings of `make check`. A law is held at a structure only
where the host has what it names: a probe asks each host which structures
it has, and each builds the files of `lib/test/property` it can. A law that
still does not build is NOT BUILT there, with the first error. Each verdict
is compared with Rune's (run 6). A difference that a line of
`tests/basis/law-deviations.txt` explains is EXPLAINED.

| Host | Pass | Fail | Not built | Not run | Differ from Rune |
|---|---:|---:|---:|---:|---:|
| MLton | 755 | 16 | 963 | 0 | 10 |
| SML/NJ 110.99.9, 64 bits | 298 | 21 | 1,273 | 142 | 18 |
| SML/NJ 110.99.9, 32 bits | 0 | 0 | 1,232 | 502 | 0 |
| SML/NJ 2026.2 | 318 | 18 | 1,273 | 125 | 16 |
| Poly/ML 5.9.2 | 471 | 10 | 1,246 | 7 | 7 |
| MLKit 4.7.23 | 564 | 23 | 1,147 | 0 | 16 |

Most laws are not built on a host because the arbitraries of the optional
structures are in files of `lib/test/property` that a host builds whole or
not at all: `sequences.sml` (the monomorphic arrays and vectors) requires
every one of their structures. SML/NJ 32 bits builds nothing that runs: its
`Word64` is wrong (`tests/lib/deviations.txt`). The laws not run are where a
program stopped: SML/NJ's "bogus fault" and "bogus overflow fault" (the
64-bit collector, `docs/bugreport/smlnj/GC`), SML/NJ 2026.2 running out of
memory at `STRING.concat`, and Poly/ML taking more than half an hour over a
date far outside 1900 to 2200.

**No difference was Rune's.** Each was probed on all six systems:

| Law | What differs | On | Class |
|---|---|---|---|
| `nRows arr = #1 (dimensions arr)` | `dimensions` of an empty array raises `Subscript` | Poly/ML | host bug |
| `~>> (i, n) = i div pow (2, Word.toInt n)` | `~>>` rounds a negative towards zero: `~>> (~1, 0w1)` is `0` on MLKit; past 62 bits on Poly/ML too | Poly/ML, MLKit | host bug |
| `fromInt (toInt i) = i` | `IntInf.toInt` raises `Overflow` at 2^31, with a 63-bit `int` | MLKit | host bug |
| `exnMessage ex` holds `exnName ex` | `exnMessage Overflow` is `"overflow"` | SML/NJ | host bug |
| `joinBaseExt (splitBaseExt p) = p` | `splitBaseExt "//"` has the base `"/"` | SML/NJ | host bug |
| `skipWS` | does not skip the vertical tab | SML/NJ | host bug |
| `STREAM_IO.input`, `input1` | `inputAll` of `TextIO.openString ""` raises `Io` from `Div`, so the arbitrary of instreams fails | SML/NJ | host bug |
| `Socket.SOCK.fromString` | `toString` of the raw type is `"RAM"` | MLKit | host bug |
| `getgrgid`, `getpwuid` | raise `Overflow` for 1000 | MLKit | host bug |
| `getiflag`'s fourth law | `getlflag` returns the `oflag` | MLton | host bug |
| `toTime (fromTimeUniv t)` | `toTime (fromTimeUniv Time.zeroTime)` raises `Date` | MLton, SML/NJ, MLKit | host bug |
| `joinDirFile (splitDirFile p) = p` | an arc that is NUL raises `InvalidArc` | SML/NJ, Poly/ML | the specification leaves valid arcs to the system |
| `PRIM_IO.compare` | the reader of `openVector` has no `getPos`, which the arbitrary of positions needs | all | the tester |
| `foldl`, `takel`, `Real64Vector.fromList` | a drawn function gives two outcomes for one argument; a real changes | SML/NJ 110.99.9, 64 bits | the host's collector (flaky) |
| `Date.year` and its five sisters | `Date` (SML/NJ, MLKit) or `Overflow` (MLton) for years outside the host's range; Poly/ML takes too long | four hosts | for the owner (below) |
| `String.tokens`, `Substring.tokens` | the predicate is called twice for each character | MLKit | for the owner (below) |

The deviations hold the host bugs and the rest, with their probes. The
owner decided the other two (2026-10-10):
- **The Date laws' years.** The specification: "A conforming `Date` structure should support date values ranging from around 1900 to 2200", and "If the resulting date is outside the range supported by the implementation, the `Date` exception is raised". The laws of `Date.year` are now two: for the years 1900 to 2200, a date of fields in range keeps them, on every implementation; for any year, it keeps them or raises `Date`, and gives no other fields. Rune's wider range is its note, `Date.date/any-year`. The first six pass on every other compiler. MLton and MLKit raise `Overflow` for a year they cannot represent (a deviation), and SML/NJ and Poly/ML take more than ten minutes over one (STOPPED).
- **`tokens` and its predicate.** The laws of `String.tokens` and `Substring.tokens` hold when `p` has no effects, as `Substring.splitl`'s does: MLKit asks `p` twice for each character, which the specification does not forbid. Rune asks once, which its reading `String.tokens/order` says and a check pins.

### Run 7, and D10 again (2026-10-10)

**Run 7**, every law on Rune at the settings of `make check`, with the
Date laws in two and `tokens` for a pure `p`: 1,740 laws at their
structures, 1,732 pass, the 8 failures the listed ones.

**D10 again**, now going on after a law where a program stops (STOPPED):

| Host | Pass | Fail | Stopped | Not built | Differ from Rune, explained | Not explained |
|---|---:|---:|---:|---:|---:|---:|
| MLton | 761 | 16 | 0 | 963 | 9 | 0 |
| SML/NJ 110.99.9, 64 bits | 404 | 16 | 47 | 1,273 | 11 | 3 |
| SML/NJ 110.99.9, 32 bits | 0 | 0 | 0 | 1,232 | 0 | 0 |
| SML/NJ 2026.2 | 424 | 12 | 31 | 1,273 | 9 | 0 |
| Poly/ML 5.9.2 | 478 | 10 | 6 | 1,246 | 7 | 0 |
| MLKit 4.7.23 | 572 | 21 | 0 | 1,147 | 14 | 0 |

The laws STOPPED are SML/NJ's crashes ("bogus overflow fault"), its
running out of memory, and laws that ran past ten minutes there; and on
Poly/ML the six Date laws for any year. The three not explained are all on
the 64-bit SML/NJ, and all its collector: in `OPTION.compose` a drawn
function gives `1` and then `8` for one argument, `MONO_VECTOR.foldr`'s
function is as inconsistent, and in `Real.?=` a drawn real prints as `0`;
probed alone, `?=` is right there. As the programs are deterministic, the
runner now runs a failing law once more by itself, and a verdict that
changes is FLAKY, the host's, and no difference.

## The owner names the law (2026-10-10)

The owner had believed the law of composition, `o`, wrong under functions
with effects, and now judges that it holds. Every run of the hunt agrees:
its four laws (Definition, Associative, Left-identity, Right-identity)
passed at the settings of `make check`, in the deep mode and on every other
compiler, with `f`, `g` and `h` drawn pure, raising and with effects, and
their calls compared. The blind test's law was not reported because it is
not wrong. What the hunt did find: the named law of `div` and `mod` (run 3),
`OS.Path.splitDirFile`'s law (the deep run), the laws the documented
exceptions broke (runs 2 and 3), a bug of Rune's `Date` (the restatement's
probe), and, on the other compilers, a dozen bugs of theirs (D10).

## `make test-laws` joins `make check` (2026-10-10)

As the owner asked. Nearly all its time was `tabulate`: at `LargeIntArray`
its law took 162 of the program's 161 seconds, a length up to 2^16 calling
`f` for a large `IntInf` each time. The laws of `tabulate` now draw lengths
up to 2^10, and those of `Array2` 32 by 32: the program takes 14 seconds.
`run-laws.sh` starts the slowest jobs first, by the times of its last full
run (`tests/out/laws.times`), and its watchdog runs beside a program, so a
job ends when the program does. A run then takes about 13 job-minutes and 2
of compiling. The longest job left is `MONO_ARRAY2` at `LargeIntArray2`,
about two minutes, nearly all of it `fromList`'s discards: rows of one
length are seldom drawn, which the general solution noted for later (variables drawn
together) would mend.


## D10 on the split library (2026-10-10 and 11)

With the arbitrary of each optional structure in a file of its own
(`lib/test/property/basis`), a compiler builds the arbitraries of every
structure it has. Three runs on the new layout, mending the tester as they
went; the last, with the settings of `make check` and against Rune's run of
the same tree:

| Host | Pass (before) | Fail | Flaky | Stopped | Not built | Not run | Differ from Rune, explained | Not explained |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| MLton | 1,524 (761) | 17 | 0 | 0 | 199 | 0 | 9 | 1 |
| SML/NJ 110.99.9, 64 bits | 545 (404) | 27 | 8 | 58 | 1,102 | 0 | 24 | 0 |
| SML/NJ 110.99.9, 32 bits | 0 (0) | 0 | 0 | 0 | 1,061 | 679 | 0 | 0 |
| SML/NJ 2026.2 | 584 (424) | 23 | 0 | 31 | 1,102 | 0 | 20 | 0 |
| Poly/ML 5.9.2 | 686 (478) | 12 | 0 | 6 | 1,036 | 0 | 9 | 0 |
| MLKit 4.7.23 | 1,444 (572) | 18 | 0 | 0 | 278 | 0 | 14 | 1 |

**No difference was Rune's.** New since the last runs:

| Law | What differs | On | Class |
|---|---|---|---|
| `abs i = (if i < 0 then ~i else i)` at `Int32` | `Int32.abs (valOf Int32.minInt)` is `~2147483648`, where `Int32.~` of it raises `Overflow`, as the 32-bit build, MLton, Poly/ML, MLKit and Rune do | SML/NJ, 64 bits (110.99.9 and 2026.2) | host bug; found now that `Int32`'s arbitrary is not in a file with `Int8`'s |
| `IMPERATIVE_IO`'s laws | `inputAll` of a stream over an empty vector raises `Io`, from `Div`, for `BinIO` as for `TextIO` (the line of `STREAM_IO.input` now says so), and the arbitraries of instreams read one to show it | SML/NJ | host bug |
| `MONO_VECTOR.tabulate` at `Real64Vector`, `MONO_ARRAY.fromList` at `Real64Array`, `LIST.mapPartial`, `MONO_ARRAY.array` at `RealArray`, `MONO_ARRAY.foldl` at `CharArray`, `MONO_VECTOR.foldr` at `RealVector` | a drawn pure function gives two outcomes for one argument, or two reals that print alike differ; by itself each fails again or the host stops ("bogus overflow fault"), and with `@SMLalloc=64M` each passes | SML/NJ 110.99.9, 64 bits | the host's collector (flaky) |
| `canInput (f, n) = StreamIO.canInput (getInstream f, n)` at `TextIO` | `TextIO.canInput` of `TextIO.openString` gives at most `SOME 32`, where `StreamIO.canInput` of its stream counts them all (33, 100, 5,000) | MLton, MLKit | for the owner (below) |

Each run of the 64-bit SML/NJ 110.99.9 brings laws of its collector anew:
the runner marks a failure FLAKY when the law by itself gives another
verdict (eight this time), and a law whose failure repeats by itself is a
line of the deviations with its probe.

**For the owner: `canInput`.** The definition, as MLton's notes quote it
(`basis-library/notes.txt`): `canInput (f, n)` returns `SOME k` "if a call
to input would return immediately with at least k characters", and it
"should attempt to return as large a k as possible". MLton and MLKit return
what their imperative buffer holds, 32 characters; their functional streams
count all. The law holds of Rune, whose imperative `canInput` is its
`StreamIO.canInput`, but asks more of other implementations than the
definition does. It stays as it is until the owner decides, and the two
differences are not explained.

**MLton's `canInput` after a read through `getInstream`.** Once the
functional stream of `getInstream f` has been read to its end,
`TextIO.canInput (f, 1)` is `SOME 0`, though `input f` still gives what `f`
holds (the same for `BinIO.openIn` of a file; every other compiler and Rune
give `SOME 1`). The fault is in MLton's `StreamIO.canInput`, which gives
`SOME 0` of that stream too: its report,
`docs/bugreport/mlton/TextIO.StreamIO.canInput/SOME-0-on-determined-stream`,
finds it fixed upstream since (MLton PR #656, in no release yet). The law
met it only through the tester's fault below; mended, no law reaches it.

**The tester.** `Prop.law` and `Prop.equalIf` showed the left side's value
before the sides ran, and showing a stream reads it through `getInstream`:
the left side met a stream already read, the right one a fresh one. On a
correct implementation that cannot be seen, but `canInput` can: Poly/ML's
`BinPrimIO.openVector` has no `readVecNB` (Rune reads the specification as
giving it one, `PrimIO.openVector/readVecNB-is-there`, as MLton does), so
`StreamIO.canInput` of a fresh stream raises `NonblockingNotSupported` and
of a read one answers. The value shown is now drawn on its own. The
`forAll`s, with one value and nothing to compare it with, still show it
before the property runs, which a case's single draw keeps
(`resource/released-after-each-case`).

**The runner** (`tests/basis/run-laws-hosts.py`):
- MLKit's probe read `WideChar.` with its full stop and so found nothing absent; it reads the lines of the errors now, as for the other hosts.
- The probe is repeated without the names it found until it finds none, as MLKit reports at most 50 errors.
- A file of host column `no` that does not build was left out by the first such file the messages named, and MLKit names every file it reads: `Int32`, `Int64`, `Word32`, `Word64`, `FixedInt` and the `Bool` and `Int` sequences were left out though MLKit has them. A file is left out now where an error points into it.
- A path under a structure that the law opens (`StreamIO` in `let open BinIO in ... StreamIO.input ...`) was asked for at the top, so sixteen laws were NOT BUILT on every compiler; where the host lacks it at the top, it is asked for under the opened structures.
- A program that does not build after twelve attempts gives NOT BUILT, not NOT RUN.
- A failing law's run by itself is tried three times where the host stops before a verdict.
- At most `$LAWS_HOST_JOBS` hosts at once (default 3): a run with all six at once, MLton building beside another session's MLton builds, ended in a crash of the machine seven minutes in (memory, most likely; not shown).

**What is still not built** is what a host lacks (`Int8`, `WideChar`,
`Real32`, the arrays of two dimensions, ...) and the hosts' own identities
of types: on MLton `Real64Vector` is not `RealVector`, `LargeWordVector`
not `Word64Vector` and `Position` not `Int`; on SML/NJ and Poly/ML
`Position` and `SysWord` are their own; MLKit's `LargeIntArray` holds
`int`. The programs take one structure's arbitrary for another's type, as
on Rune they are one; a program made for each host would build them. The
32-bit SML/NJ builds the library now, but every program stops as it loads
the arbitraries of numbers, with `Domain` from `Gen.largeRange`: there
`Word64.notb 0w0` is 18446744070488326143, not 2^64 - 1 (bits 30 and 31
lost, `tests/lib/deviations.txt`), so the widest range `Gen` allows is too
narrow.

## The owner's decisions (2026-10-11)

The owner asked for three things: the hosts' bugs filed under
`docs/bugreport`, the law of `canInput` restated, and a law program for
each host.

**The bug reports.** Each bug the hunt found on another compiler is a
report in `docs/bugreport/HOST/`, in the form of those already there: a
program that shows it with the host's own Basis Library, its output on
every build, the cause in the host's sources, a fix and how it was checked
(no compiler was rebuilt; the patched code was run on the release), and
what the host's tracker has of it. Nothing was posted. The lines of
`tests/basis/law-deviations.txt` name their reports.

| Host | Report | Upstream |
|---|---|---|
| MLton | `Posix.TTY.getlflag/returns-oflag` | not reported; so since 2001 |
| MLton | `Date.date/Overflow-not-Date` | not reported |
| MLton | `Date.toTime/offset-read-at-zone-offset-of-now` | not reported; `master` has a regression of its own (PR #654) |
| MLton | `TextIO.StreamIO.canInput/SOME-0-on-determined-stream` | fixed (PR #656), in no release yet |
| Poly/ML | `Array2.dimensions/no-rows-Subscript` | not reported |
| Poly/ML | `IntInf/shift-right-rounds-towards-zero` | polyml#243, fixed on `master` |
| MLKit | `IntInf/shift-right-rounds-towards-zero` | not reported |
| MLKit | `IntInf/shift-right-by-30-or-more` (found on the way: any `~>>` by 30 or more bits gives 0) | not reported |
| MLKit | `Socket.SOCK.toString/raw-is-RAM` | not reported |
| MLKit | `Date.date/Overflow-not-Date` | not reported |
| MLKit | `Date.toTime/before-1970`, extended (London in 1970) | not reported |
| MLKit | `IntInf.toInt` is `Time.toSeconds/beyond-2^31-seconds`, already there | mlkit#230, fixed (PR #234) |
| MLKit | `getgrgid` and `getpwuid` are `Posix.SysDB.getpwuid/untagged-results`, already there | not reported |
| SML/NJ | `General.exnMessage/name-missing` | not reported |
| SML/NJ | `OS.Path.splitBaseExt/empty-arc-dropped` (more than `"//"`) | not reported |
| SML/NJ | `Int.scan/whitespace-vt-ff-cr` | `skipWS` is smlnj#447, fixed; the scanners of integers not reported |
| SML/NJ | `TextIO.inputAll/empty-stream-Div` | smlnj#449, fixed in both lines |
| SML/NJ | `Int32.abs/minInt-on-64-bit` | smlnj#444, fixed in the 2026 line only |
| SML/NJ | `Date.toTime/local-offset-applied` | in part smlnj#452 (2026.3) |
| SML/NJ | `TextIO.canInput/loses-input` | not reported (below) |

The law of `toTime (fromTimeUniv t)` failed at the epoch on three of them
for one reason in three forms: the United Kingdom kept UTC+1 all year from
1968-10-27 to 1971-10-31, and MLton, MLKit and SML/NJ each convert a date
at an offset through the zone's offset of another day, so a date of 1970
comes out an hour early, the epoch before itself, and `Date` is raised.
Poly/ML and Rune convert by the calendar. Some older reports' Status lines
are behind their trackers (MLKit's #230 to #233, closed by PR #234; MLton's
#658, closed): they are left for the owner.

**`canInput` restated.** As the owner decided, the laws are what the
definition promises of any implementation: `SOME k` with `k <= n` means
that `k` elements can be read (by `input1`), and `canInput` is `NONE`
exactly when the stream's is. Rune's full count is its reading,
`IMPERATIVE_IO.canInput/counts-the-stream`, pinned by an example of
`TextIO.canInput`. Choosing the laws found two more bugs. SML/NJ's
`canInput` loses input: after `canInput (TextIO.openString "ab", 5)`,
which is `SOME 2`, `input` gives `""`, as each chunk read is linked to the
stream's first buffer in place of the one before it (and the count comes
back short). MLton's `StreamIO.canInput` is `SOME 0` of a stream whose
buffer is spent and whose next one is read (above). The laws hold on MLton,
Poly/ML, MLKit and Rune; on SML/NJ they cannot be made, its `inputAll` of
an empty stream raising `Io`.

**A program for each host.** `runedoc --laws` writes, beside each program,
the alternative entry of each law that draws its types by the arbitraries
of its structure's own family (`Real64VectorArb` for
`Real64Vector.vector`, `PositionArb` for `Position.int`), where Rune's
types are one and the entry takes another's (`LargeRealVectorArb`,
`IntArb`). The runner builds each host a program of its own: a law's entry,
or its alternative where the host lacks what the entry names or the entry
does not build there. Rune's programs are as before. The run, with the
restated laws (1,742 at their structures):

| Host | Pass (before) | Fail | Flaky | Stopped | Not built (before) | By their alternatives | Not explained |
|---|---:|---:|---:|---:|---:|---:|---:|
| MLton | 1,707 (1,524) | 16 | 0 | 0 | 19 (199) | 180 | 0 |
| SML/NJ 110.99.9, 64 bits | 571 (545) | 25 | 9 | 62 | 1,075 (1,102) | 27 | 0 |
| SML/NJ 110.99.9, 32 bits | 0 (0) | 0 | 0 | 0 | 1,061 (1,061) | 0 | 0 |
| SML/NJ 2026.2 | 609 (584) | 25 | 0 | 33 | 1,075 (1,102) | 27 | 0 |
| Poly/ML 5.9.2 | 715 (686) | 12 | 0 | 6 | 1,009 (1,036) | 27 | 0 |
| MLKit 4.7.23 | 1,447 (1,444) | 17 | 0 | 0 | 278 (278) | 0 | 0 |

No difference is unexplained. What MLton still does not build is five laws
of structures it lacks (`INet6Sock`, `WideTextPrimIO`, `SML90`) and
fourteen whose types are another structure's, which Rune's are one with
`int` or `word`: `SysWord.word` in `Posix`'s conversions, `Position.int`
in `Posix.IO.FLock` and as `BinPrimIO.pos`, and `Word.word`, the amount of
`SysWord`'s shifts. The entry draws them by `IntArb` and `WordArb`, the
alternative prefers only the law's own structure's family, and on MLton
`int` and `word` have 32 bits where `Position` and `SysWord` have 64.
Neither entry fits there; an alternative by the name the signature gives
each type would. MLKit's are its own types (its `LargeIntArray`
holds `Word64.word`; `LargeIntVector/elem-is-Word64`) and the structures it
lacks. The 32-bit SML/NJ's programs still stop as they load (above).

## `Position` and `SysWord`, types of their own (2026-10-11)

The fourteen laws that no host but Rune built were all of `Position.int`
and `SysWord.word`, which Rune made `int` and `word`. The specification
makes them the same as nothing: "The type Position.int is used to represent
positions in files and I/O streams", and "The type SysWord.word is
guaranteed to be large enough to hold any unsigned integral value used by
the underlying system", which on a 64-bit system has 64 bits, so Rune's
63-bit `SysWord` was too small. MLton (`Position` is `Int64`, `SysWord`
`Word64`), SML/NJ (`Int64`, a 64-bit word of its own) and Poly/ML
(`LargeInt`, `LargeWord`) keep both apart from `Int` and `Word`; MLKit,
like Rune before, does not. The owner decided to keep them apart:
`Position :> INTEGER = Int64` and `SysWord :> WORD = Word64`, each a type
of its own of 64 bits, whose constants are converted where they are
evaluated (commit `5abdae70`). The Basis converts where the VM's ints and
words meet them; the Basis suite (139,221 checks), the examples and the
laws pass, and the generators' hash is renewed for P1 (without the two
types it is unchanged).

D10 with them:

| Host | Pass (before) | Fail | Flaky | Stopped | Not built (before) | By their alternatives | Not explained |
|---|---:|---:|---:|---:|---:|---:|---:|
| MLton | 1,721 (1,707) | 16 | 0 | 0 | 5 (19) | 153 | 0 |
| SML/NJ 110.99.9, 64 bits | 586 (571) | 28 | 12 | 55 | 1,061 (1,075) | 0 | 0 |
| SML/NJ 110.99.9, 32 bits | 0 (0) | 0 | 0 | 0 | 1,061 (1,061) | 0 | 0 |
| SML/NJ 2026.2 | 622 (609) | 26 | 0 | 33 | 1,061 (1,075) | 0 | 0 |
| Poly/ML 5.9.2 | 728 (715) | 13 | 0 | 6 | 995 (1,009) | 0 | 1 |
| MLKit 4.7.23 | 1,447 (1,447) | 17 | 0 | 0 | 278 (278) | 0 | 0 |

Every law not built on MLton, SML/NJ and Poly/ML is now of a structure the
host lacks (on Poly/ML `INet6Sock` too, whose arbitrary it cannot build).

**For the owner: `wordToFD`.** The law `fdToWord (wordToFD w) = w`, for
`SysWord.<= (w, SysWord.fromInt (valOf Int.maxInt))`, newly built on
Poly/ML, fails there at `w = 0wx80000000`, which comes back as
`0wxFFFFFFFF80000000`. Poly/ML and MLton keep a descriptor in a C `int` of
32 bits, so a word of 2^31 or more wraps; MLton passes only because its
`Int.maxInt` is 2^31 - 1, and SML/NJ, MLKit and Rune keep the word. A
descriptor of POSIX is "a per-process unique, non-negative integer", a C
`int`, which POSIX makes at least 32 bits wide (`{INT_MAX}` is at least
2147483647) but not exactly 32, and the condition was written to Rune's,
an `int` of 63 bits: the law asked more than the specification of words
that a system's `int` need not hold. The owner had it restated
(2026-10-11): the law holds for `SysWord.<= (w, 0wx7FFFFFFF)`, the largest
number every POSIX system's `int` holds, and the page says why; the
counterexample beyond Rune's `int` stays. It passes on MLton, Poly/ML,
SML/NJ 2026.2, MLKit and Rune, and no difference is left unexplained. The
laws of `wordToPid`, `wordToUid` and `wordToGid` keep their condition.

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

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

## Run 1

(To be filled in.)

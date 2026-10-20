# SML/NJ 110.99.9 for 64 bits: a deterministic program stops now and then with "bogus overflow fault", but never with the addresses fixed

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** `tests/lib/unicode/normalize_props.sml`, ten
properties of `lib/unicode`'s `Normalize` drawn by `lib/test/property` from
fixed seeds, passes on every run of MLton, Poly/ML, MLKit, SML/NJ 2026.2,
SML/NJ 110.99.9 for 32 bits and Rune. On SML/NJ 110.99.9 for 64 bits it
stops now and then, in a different property each time, with

```
/home/.../bin/sml: Fatal error -- bogus overflow fault: pc = 0x7ac070450659, sig = 11
```

## Status: not reduced, not reported upstream

Found on 2026-10-18 (docs/plans/utf8.md, M5), in `make test-lib-hosts`.

## What happens

The program is the one `tests/lib/run-hosts.sh` runs as
`unicode.normalize-props`: `sml`, given the files of `lib/random`,
`lib/test/property`, `lib/test/unit` and `lib/unicode` that their MANIFESTs
mark `host yes`, then the test and a file that exits.

- With the kernel's address randomisation, 4 runs of 45 stopped (one of them
  in `make test-lib-hosts`), after two to six of the ten properties had
  passed.
- With it off (`setarch x86_64 -R sml ...`), none of 20 stopped.
- The faulting pc ends in `...0659` in every run: the same instruction,
  wherever it is mapped.

A program whose every input is fixed that fails only for some addresses
points to the collector or to a value read as an address. The 64-bit build
has two known faults of that kind, in `GC/real-corrupted-on-64-bit` (a real
or a `Word64` not saved across a collection) and
`GC/spilled-word64-argument` (a raw `Word64` among the pointers of a record
of arguments). `lib/test/property` draws its cases with `Word64` arithmetic.
Which of them this is, if either, has not been found.

## What it breaks

`tests/lib/unit/core.sml` stops the same way. One of 30 runs with
`@SMLalloc=512k` died at a pc ending in `0659`, and the GitHub-hosted
nightly of 2026-10-20 (run 39394299943) failed `smlnj-legacy unit.core`.
The nightly of 2026-10-19 passed that test, and on the failing run
MLton, SML/NJ 110.99.9 for 32 bits, SML/NJ 2026.2, Poly/ML and MLKit
passed it. The test draws its two properties through `lib/test/property`.

`tests/lib/deviations.txt` has a `HOST-FLAKY` line for
`unicode.normalize-props` and for `unit.core` on `native:smlnj-legacy`,
as it has for `property.shrink`. The library is not changed for it
(AGENTS.md).

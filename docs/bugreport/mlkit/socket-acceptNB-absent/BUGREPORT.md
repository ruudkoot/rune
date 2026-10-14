# MLKit 4.7.23: `Socket` has no `acceptNB`

**Class 2 of 4: the host lacks a member of the specification.** The Basis
Library's `SOCKET` signature specifies `acceptNB`, the accept that does
not wait; MLKit's `Socket` has `accept` and not `acceptNB`, so a program
that names it does not compile:

```
unbound identifier Socket.acceptNB.
```

## Status: not reported upstream

**Still so in MLKit 4.7.25** (2026-10-09): `acceptNB`, like `connectNB`,
is commented out of its `SOCKET` signature, and `zmtp.zmtp` does not
compile (2026-10-13).

## What it breaks

`lib/zmtp` serves the peers of a bound socket from one loop and accepts
without waiting, so `zmtp.zmtp` and `jupyter.jupyter` (which is written on
`lib/zmtp`) do not compile on MLKit (`tests/lib/deviations.txt`,
`HOST-ABSENT`). The library is not changed for it (AGENTS.md).

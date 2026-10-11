# Poly/ML 5.9.2: `Socket.recvVecNB` blocks on a socket that `accept` gave

**Class 1 of 4: a fault of the implementation, which no reading of a
specification bears on.** The Basis Library's `recvVecNB` is the
non-blocking receive: "if the operation would block, it returns NONE".
On a socket that `Socket.accept` or `Socket.acceptNB` returned, Poly/ML
waits for data instead, for ever if none comes. On the socket that
connected, the same call returns `NONE` at once, as it should. MLton and
Rune return `NONE` on both.

## Status: not reported upstream

## What happens

`repro.sml` listens on the loopback interface, connects to itself,
accepts, and receives without blocking on the accepted socket, where
nothing has been sent:

```
$ poly -q < repro.sml
...
accepted
```

and it waits there. With the receive on the connecting socket `c`
instead of the accepted `a`, it prints `NONE: would block`; with
`Socket.accept` in place of `acceptNB` it waits as well.

## What it breaks

`lib/zmtp`'s sockets serve their peers from one loop (`Zmtp.wait`), and
read a connection that a bound socket accepted with `recvVecNB`, so
`tests/lib/zmtp/zmtp.sml` hangs under Poly/ML at its first `wait`
(`tests/lib/deviations.txt`, `native:polyml | zmtp.zmtp`). The library is
not changed for it (AGENTS.md).

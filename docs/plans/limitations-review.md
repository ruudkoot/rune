# The limitations and the notes no check pins

A review of 2026-09-21. `readings.md` listed five `Limitation:` notes and
`coverage.md` twelve notes that no check of the suite pins. **Eight of the
twelve are fixed**, leaving four, and the limitations are down to two. What
is left is below with what it would take.

## Fixed

| Note | What was wrong | What it is now |
| --- | --- | --- |
| `INET_SOCK/ipv4-only` (Limitation) | said there is no IPv6 | there is: `INET6_SOCK`. The note is an `Implementation:` saying that *this* signature is the specification's and the specification's Internet sockets are IPv4 |
| `SOCKET/no-ipv6` (Limitation) | the same | an `Implementation:` saying that `AF.list` "returns a list of all the available address families", so the set is the system's, and `INET6` is among them |
| `MONO_VECTOR.vector/not-abstract` (Deviation) | said an `IntVector.vector` is an `int vector` | it is not: the monomorphic families are sealed, which costs nothing |
| `MONO_ARRAY2.array/not-abstract` (Deviation) | the same for the two-dimensional arrays | the same, built on the implementation under the sealed `Array2` |
| `IMPERATIVE_IO.instream/admits-equality` | no check pinned it | pinned by `TextIO.instream/equal-when-the-same-stream` |
| `WideTextIO/file-streams-have-no-positions` (Limitation) | no check pinned it | pinned by `WideTextIO.openIn/the-reader-has-no-positions` |
| `ImperativeIO/not-sealed` (Deviation) | the public functor was not ascribed `IMPERATIVE_IO` | `sig_imperative_io.sml` moved before `io_functors.sml` in the MANIFEST and the functor is ascribed; a program now sees what the signature names |
| `IMPERATIVE_IO/functor-not-sealed` (Deviation) | the same from the signature's side | an `Implementation:` note saying the public functor is sealed and the library's own `RuneImperativeIOFn` is not, because `TextIO`, `BinIO` and `WideTextIO` take the streams apart and the constructors are not in the signature |

## Left open, and why

None of these can be pinned by a check of the suite, because none of them is
something a running program can observe. What holds them is the generated
documentation, which `make check` compares with the library as it stands.

| Note | Kind | Why it stays |
| --- | --- | --- |
| `MONO_VECTOR_EQ/not-in-the-specification` | **left open** | The library has a signature the specification does not, so that `WideString.string` can be a type name and its constants can be overloaded at it. Nothing to fix: the signature is needed, and its absence from the specification is a fact about the specification. A program never sees it -- the seal files show `MONO_VECTOR`. |
| `StreamIO/takes-the-slice-structures` | **left open** | The specification's functor is given no way to make the vector slices its writer takes, so MLton's takes them too and so does this one. Fixing it means the specification changing. A check cannot see a functor's argument list. |
| `SML90/is-history` | **left open** | The page that defined `SML90` is no longer among the specification's; this one is transcribed from MLton's library. There is nothing to fix and nothing to check. |
| `SML90.Interrupt/never-raised` | **hard** | The exception is declared and nothing raises it, because the VM handles no signal: an interrupt ends the program. Raising it needs the VM to catch `SIGINT` and the interpreter to check a flag at safe points -- a real change to the runtime, with a cost on every loop, for an exception the specification itself calls obsolete. A check cannot prove that something is never raised either. |

## What was learned doing the `ImperativeIO` one

Sealing the library's own `RuneImperativeIOFn` does not work and should not
be tried again: `TextIO`, `BinIO` and `WideTextIO` pattern-match `InStream`
and `OutStream`, and those constructors are not in `IMPERATIVE_IO`. Only the
public functor, whose callers are programs, can be sealed -- which is the
same shape as the `seal` files: the library keeps the whole structure, a
program sees the signature.

## Recommendation

Leave the four: two are facts about the specification (`SML90`'s page is
gone; the `StreamIO` functor has to take slice structures the specification
gives it no way to make), one is a signature the library needs and a program
never sees (`MONO_VECTOR_EQ`), and one is a signal handler the runtime does
not have (`SML90.Interrupt`).

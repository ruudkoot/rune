# MLKit 4.7.23: `Socket.SOCK.toString` names the raw socket type `"RAM"`, which `fromString` does not read back

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** SML/NJ (110.99.9 and 2026.2) and Poly/ML name it `"RAW"` and read it back; MLton's `SOCK.list ()` has no raw type.

## Status

Not reported upstream from here. MLKit `master` at `5bffdc3` (2026-10-09)
has the same code: `basis/Socket.sml` is identical to 4.7.23's. A search
of MLKit's issues and pull requests (`Socket`, `SOCK`, `RAW`, 2026-10-11)
found no report of it.

## Summary

* **The trigger:** `Socket.SOCK.toString` of the raw socket type, the one
  that `Socket.SOCK.list ()` pairs with `"RAW"`.
* **What goes wrong:** it is `"RAM"`, and `Socket.SOCK.fromString "RAM"`
  is `NONE`.
* **Required behaviour:** the
  [`SOCKET` specification](https://smlfamily.github.io/Basis/socket.html),
  of `SOCK.list`: "The list of possible socket type names includes
  "STREAM" for stream sockets, "DGRAM" for datagram sockets, and "RAW" for
  raw sockets. These names are formed by taking the symbolic constants
  from the C API and removing the leading SOCK_."; and of `SOCK.toString`
  and `SOCK.fromString`: "These convert between a socket type value and
  its name (e.g., "STREAM"). ... If a pair (name,sty) is in the list
  returned by list, then it is the case that name is equal to
  toString(sty)."

## Environment

* **MLKit:** v4.7.23 ("MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]"), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2 (kernel 6.18), glibc
  2.39.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "If a pair (name,sty) is in the list returned by list, then it is the
   case that name is equal to toString(sty)"; the names include "RAW" for
   raw sockets, and fromString reads a name back. *)
structure S = Socket.SOCK
fun opt NONE = "NONE"
  | opt (SOME t) = "SOME " ^ S.toString t
val () = List.app (fn (name, sty) =>
           print ("list: " ^ name ^ "   toString: " ^ S.toString sty
                  ^ "   fromString (toString): " ^ opt (S.fromString (S.toString sty)) ^ "\n"))
         (S.list ())
```

```
$ mlkit -o bug bug.mlb && ./bug
list: DGRAM   toString: DGRAM   fromString (toString): SOME DGRAM
list: RAW   toString: RAM   fromString (toString): NONE
list: STREAM   toString: STREAM   fromString (toString): SOME STREAM
```

## The cause

A typing slip in `basis/Socket.sml`, structure `SOCK` (line 86), between a
`list` and a `fromString` that both say `"RAW"`:

```sml
      fun list () = [("DGRAM",SOCK_DGRAM),
                     ("RAW",SOCK_RAW),
                     ("STREAM",SOCK_STREAM)]
      fun toString i =
          if i = SOCK_DGRAM then "DGRAM"
          else if i = SOCK_RAW then "RAM"
          else if i = SOCK_STREAM then "STREAM"
          else raise Fail "Socket.SOCK.toString: impossible"
      fun fromString "DGRAM" = SOME SOCK_DGRAM
        | fromString "RAW" = SOME SOCK_RAW
        | fromString "STREAM" = SOME SOCK_STREAM
        | fromString _ = NONE
```

## The fix

`fix.patch`:

```diff
--- a/basis/Socket.sml
+++ b/basis/Socket.sml
@@ -83,7 +83,7 @@
                      ("STREAM",SOCK_STREAM)]
       fun toString i =
           if i = SOCK_DGRAM then "DGRAM"
-          else if i = SOCK_RAW then "RAM"
+          else if i = SOCK_RAW then "RAW"
           else if i = SOCK_STREAM then "STREAM"
           else raise Fail "Socket.SOCK.toString: impossible"
       fun fromString "DGRAM" = SOME SOCK_DGRAM
```

**Tested:** `fix.patch` applied to a copy of the library of the installed
MLKit 4.7.23 (`lib/mlkit`), with `SML_LIB` pointing at the copy, so that
`mlkit` recompiled `Socket.sml`; `bug.sml` then prints

```
list: DGRAM   toString: DGRAM   fromString (toString): SOME DGRAM
list: RAW   toString: RAW   fromString (toString): SOME RAW
list: STREAM   toString: STREAM   fromString (toString): SOME STREAM
```

The compiler itself was not rebuilt, nor `master`.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` of
`lib/basis/*.sml` is tested on generated values, and
`tests/basis/run-laws-hosts.py` runs them against MLKit's own Basis
Library (`docs/plans/quickcheck-hunt.md`, the sections on the other
compilers). The law of `SOCK.fromString` in `lib/basis/sig_socket.sml`,

```
Law: `SOCK.fromString (SOCK.toString st) = SOME st`
```

with `st` drawn from `SOCK.list ()`, fails at `Socket` on MLKit for the
raw type. The line of `tests/basis/law-deviations.txt`:

```
native:mlkit | SOCKET.SOCK.fromString/law-1@Socket | HOST-BUG | Socket.SOCK.toString of the raw type is "RAM", which fromString does not read back
```

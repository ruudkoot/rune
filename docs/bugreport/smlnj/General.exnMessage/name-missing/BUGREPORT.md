# SML/NJ 110.99.9 and 2026.2: `exnMessage` of `Bind`, `Match`, `Div`, `Domain`, `Overflow`, `Size` and `Subscript` does not contain the exception's name

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`exnMessage` and these exceptions (searched 2026-10-11). `exn-name.sml` is
the same in 110.99.9, in smlnj/legacy at `6ed5a0a` (2026-09-13) and in
smlnj/smlnj at `17362d2` (2026-09-24), so 2026.3 has it too (by reading the
code).

**What is worth sending SML/NJ:** a new issue on smlnj/legacy, with
`bug.sml` and `fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** `exnMessage ex` for seven of the Basis's own
  exceptions.
* **What goes wrong:** the message is a phrase without the name:
  `exnMessage Div` is `"divide by zero"`, `exnMessage Overflow` is
  `"overflow"`, `exnMessage Size` is `"size"`. Only `Fail`, `SysErr`, `Io`
  and the exceptions without a special message (`Chr`, `Empty`, ...) are
  right.
* **Required behaviour:** the
  [Basis `GENERAL` specification](https://smlfamily.github.io/Basis/general.html#SIG:GENERAL.exnMessage:VAL):
  "`exnMessage ex` returns a message corresponding to exception `ex`. The
  precise format of the message may vary between implementations and
  locales, but will at least contain the string `exnName ex`." Its example
  is this very case: `exnMessage Div = "Div"`. MLton, Poly/ML, MLKit and
  Rune give `"Div"`, `"Overflow"` and so on.

## Where it happens

| Build | wrong of 13 |
|---|---|
| 110.99.9, 64-bit | 7 |
| 110.99.9, 32-bit | 7 |
| 2026.2 (64-bit) | 7 |
| `fix.diff`, as a standalone copy (`fix-check.sml`) | 0 of 18 |

```
$ sml bug.sml                           # 110.99.9 (32 or 64 bits) or 2026.2
exnMessage Bind = "nonexhaustive binding failure": WRONG (no "Bind")
exnMessage Match = "nonexhaustive match failure": WRONG (no "Match")
exnMessage Div = "divide by zero": WRONG (no "Div")
exnMessage Domain = "domain error": WRONG (no "Domain")
exnMessage Overflow = "overflow": WRONG (no "Overflow")
exnMessage Size = "size": WRONG (no "Size")
exnMessage Subscript = "subscript out of bounds": WRONG (no "Subscript")
exnMessage Chr = "Chr": ok
exnMessage Empty = "Empty": ok
exnMessage Option = "Option": ok
exnMessage Span = "Span": ok
exnMessage Fail = "Fail: why": ok
exnMessage SysErr = "SysErr: No such file": ok
```

The phrase also ends up inside other messages: the message of an `Io`
whose cause is `Div` is `Io: inputAll failed on "<string>" with exception
divide by zero`.

## The cause

`base/system/Basis/Implementation/exn-name.sml` gives these seven a phrase
of their own:

```sml
      | exnMessage (Fail s) = "Fail: " ^ s
(** NOTE: we should probably include line/file info for Match and Bind *)
      | exnMessage Bind = "nonexhaustive binding failure"
      | exnMessage Match = "nonexhaustive match failure"
      | exnMessage Subscript = "subscript out of bounds"
      | exnMessage Size = "size"
      | exnMessage Overflow = "overflow"
      | exnMessage Div = "divide by zero"
      | exnMessage Domain = "domain error"
      | exnMessage e = exnName e
```

`Fail`, `SysErr` and `Io` already put the name in front (`"Fail: "`,
`"SysErr: "`, `"Io: "`).

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9,
and to smlnj/smlnj with `git apply -p2`, as the file is the same there)
puts the name in front of the five phrases that say more than the name,
`"Div: divide by zero"` and so on, as `Fail` does. `Size` and `Overflow`,
whose phrases are only the name in lower case, fall through to
`exnName e`.

The top level prints an uncaught exception as `name [message]`, or as
`name` alone when the two are equal (`evalloop.sml`). It would print
`uncaught exception Div [Div: divide by zero]`, as it prints
`uncaught exception Fail [Fail: why]` now, and `uncaught exception
Overflow` without the brackets.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` holds the
patched `exnMessage`, copied whole into a standalone program; on 110.99.9
(32 and 64 bits) and 2026.2 it gives a message with `exnName ex` for all
18 exceptions it tries, `Io` with the cause `Div` among them.

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The law of `exnMessage`
(`lib/basis/sig_general.sml`), `String.isSubstring (exnName ex)
(exnMessage ex) = true`, fails on SML/NJ for `Overflow` and `Div`; it is
the line `native:smlnj* | GENERAL.exnMessage/law-1@General` of
`tests/basis/law-deviations.txt`. Rune's Basis suite had found it before:
the line `native:smlnj*@* | General.exnMessage/contains-exnName-*` of
`tests/basis/deviations.txt`.

# HaMLet 2.0.1: a string constant is silently cut short at its first byte above 127 or escape above 255

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9, Poly/ML 5.9.2, MLKit 4.7.25 and Moscow ML 2.10.1) does this.** HaMLet runs a program whose string constant the Definition rejects, and gives the constant only the characters before the first one it cannot convert; Poly/ML and MLton refuse these programs, SML/NJ, MLKit and Moscow ML keep the raw bytes, and all five refuse the escapes.

## Status: not reported upstream

This has not been sent to HaMLet. HaMLet's `master` at `37275b9`
(2025-10-17), still its newest commit on 2026-10-19, is the commit built
here. `parse/Lexer.lex` and `lib/LibrarySVal.sml` have not changed since
"Release 2.0.1" (`7e88545`, 2025-07-27). The branch `succ` (HaMLet S, at
`4d8ddb5`, 2025-10-17) has the same class `printable` in its
`parse/Lexer.lex` and the same `stringFromString` in its `lib/Library.sml`.

A search of rossberg/hamlet's issues and pull requests, their titles,
texts and comments, all eleven up to #11 of 2025-07-26, found no report of
it (2026-10-19). The words searched for were "fromString", "ASCII",
"Unicode", "UTF", "Latin", "printable", "string literal", "string
constant", "character", "char", "byte", "lexer" and "lex".

## Summary

* **The trigger:** a string constant in which a character that the Basis
  Library's `String.fromString` cannot convert comes after one that it
  can:
  * a raw byte from 128 to 255: a Latin-1 character such as `é` (E9), or
    any byte of UTF-8;
  * an escape for a character above 255, `\u0100` to `\uFFFF` or `\256`
    to `\999`.
* **What goes wrong:** HaMLet runs the program, without a warning, and the
  constant holds only the characters before that one. The rest is lost.
  * `"caf<E9>"` is `"caf"` (`bug.sml`). So is `"caf<E8>"`: the two compare
    equal, and the pattern `"caf<E9>"` matches `"caf"` (`bug-equal.sml`).
  * `"a<U+202E>b"` is `"a"`, and `"e<U+0301>"` is `"e"` (`bug-utf8.sml`).
  * `"a\u0100b"` and `"a\256b"` are `"a"` (`bug-escape.sml`).
  * After a gap `\...\` the constant is empty (`bug-cases.sml`).
  * Where the character is the first of the constant, the program is
    refused, with "special constant out of range" (`refused-first.sml`),
    and so is a character constant that holds it (`refused-char.sml`).
* **Required behaviour:** the
  [Definition of Standard ML (Revised)](https://smlfamily.github.io/sml97-defn.pdf),
  Section 2.2, makes a string constant "a sequence, between quotes ("), of
  zero or more printable characters (i.e., numbered 33-126), spaces or
  escape sequences", and `\ddd` and `\uxxxx` the character of that number,
  "an integer in the ordinal range of the alphabet". Appendix E.1: "it is
  a compile-time error if the constant does not make sense or does not
  denote a value within the machine representation chosen for the type.
  For example, an escape sequence of the form \uxxxx in a string constant
  of 8-bit characters only makes sense if xxxx denotes a number in the
  range [0, 255]." HaMLet may refuse every program here but
  `ok-escape.sml`; it must not run one with another string. Poly/ML 5.9.2
  and MLton 20241230 refuse them. SML/NJ 110.99.9, MLKit 4.7.25 and Moscow
  ML 2.10.1 keep a raw byte as one character (`"caf<E9>"` has four), and
  refuse `bug-escape.sml`.

## Environment

* **HaMLet:** 2.0.1, from github.com/rossberg/hamlet at `37275b9` (its
  `main/Main.sml` names 2.0.1), built by `make with-mlton` with MLton
  20241230, as Rune's `scripts/fetch-hosts.sh` (branch `hamlet`) builds
  it, with Rune's `scripts/hamlet/hamlet.patch` applied (SHA-256
  `592665341a63...`, as the install's `patch.sha256` records). The patch
  adds to HaMLet's Basis Library and its driver (`HAMLET_QUIET` among
  them), and changes how the elaborator resolves flexible records. It
  leaves `parse/`, `syntax/` and `lib/LibrarySVal.sml` alone, and the same
  commit built without it gives the same output of `run.sh`.
* **System:** Linux x86-64, Ubuntu 24.04.1 under WSL2.
* **Basis Library: HaMLet's own,** the `basis` directory that HaMLet
  interprets with every program. The value of a constant is computed by
  HaMLet itself, with the Basis Library of MLton, which compiled it.
  Nothing of Rune is involved.

## What happens

`bug.sml`, where `<E9>` stands for the one byte E9 that the file holds:

```sml
(* The Definition of Standard ML (Revised), Section 2.2: a string constant
   holds printable characters (numbered 33-126), spaces and escape
   sequences. The literal below holds the byte E9 (e acute in Latin-1)
   after "caf", so the program must be rejected. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val s = "caf<E9>"
val () = print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
```

```
$ hamlet bug.sml
size=3 bytes=99 97 102
```

HaMLet without Rune's patch also shows the value it bound:

```
$ hamlet-mlton -b basis bug.sml
[loading standard basis library]
[processing bug.sml]
size=3 bytes=99 97 102
val bytes = _fn : string -> string
val s = "caf" : string
```

`run.sh` runs all the programs (`HAMLET=/path/to/hamlet sh run.sh`):

```
bug           size=3 bytes=99 97 102
bug-utf8      size=1 bytes=97
              size=1 bytes=101
bug-cases     ab: size=2 bytes=97 98
              an escape: size=1 bytes=10
              a gap: size=0 bytes=
bug-escape    size=1 bytes=97
              size=1 bytes=97
bug-equal     true
              matched
refused-first refused-first.sml:2.8-2.14: special constant out of range
refused-char  refused-char.sml:2.8-2.12: special constant out of range
ok-escape     size=4 bytes=99 97 102 233
```

Every byte from 128 to 255 does the same: in `"x<byte>y"` each gives a
string of one character, and as the first character of a constant, in a
program of its own, each is refused. `ok-escape.sml` writes `é` as the
escape `\233`, which the Definition allows, and gets its four characters.

## The cause

The lexer and the conversion that gives a constant its value disagree on
what may stand in a string.

The lexer, `parse/Lexer.lex` lines 137-143, takes as "printable" every
character but 0 to 32, `"`, DEL and `\`, and the lexer is `%full`, of
characters 0 to 255:

```
  printable  = [^\000-\032"\127\\];
  escape     = "\\a" | "\\b" | "\\t" | "\\n" | "\\v" | "\\f" | "\\r" |
	       ("\\^"[@-_])  | ("\\"{digit}{3})  | ("\\u"{hexdigit}{4}) |
	       "\\\"" | "\\\\";
  gap        = ("\\"{formatting}"\\");
  stringchar = {printable} | " " | {escape};
  string     = "\""({stringchar} | {gap})*"\"";
```

So bytes 128 to 255 are taken, and any three digits or four hexadecimal
digits make an escape. The token keeps the text between the quotes
(`toString`, line 96): "Special constants are represented as strings
containing the distinguished part of their lexical appearance -- their
actual values cannot be calculated before overloading resolution"
(`doc/Manual.tex`, line 700).

The value is computed from that text in `lib/LibrarySVal.sml`, lines
54-56:

```sml
  fun stringFromString(s, t_opt) =
        STRING(valOf(String.fromString s))
          handle Option => raise Overflow
```

The elaborator calls it to check the range of the constant
(`elab/ElabCore.sml`, lines 89-102, where `Overflow` becomes "special
constant out of range"), the evaluator for its value (`valSCon`,
`eval/EvalCore.sml` line 46, through `DynamicLibrary`, which opens
`LibrarySVal`), and the match checker to compare patterns (`normalise`,
`elab/CheckPattern.sml` line 67).

`String.fromString` is that of the system HaMLet is compiled with, here
MLton, and it does what the Basis Library specifies (STRING):

> They return as many characters as can successfully be scanned, stopping
> when they reach the end of the source or a non-printing character (i.e.,
> one not satisfying isPrint), or if they encounter an improper escape
> sequence. fromString ignores the remaining characters [...] If no
> conversion is possible, e.g., if the first character is non-printable or
> begins an illegal escape sequence, NONE is returned.

and "if any prefix of the input is successfully scanned, including an
escaped formatting sequence, the functions returns some string". A byte
above 126 does not satisfy `isPrint`, and MLton's `Char.scan` gives `NONE`
for an escape above 255, which no 8-bit character holds. So
`String.fromString` of the four characters `c`, `a`, `f` and 233 is
`SOME "caf"`, which HaMLet takes for the value. Only where nothing before
the character converts is the result `NONE`, and the program refused.

The fault is HaMLet's, which takes the prefix for the whole: any Basis
Library that follows the specification gives the same prefix, so a
HaMLet compiled by SML/NJ or Poly/ML should behave alike (not tried).
`charFromString` (lines 58-60) uses `Char.fromString` in the same way,
but a character constant holds one character, so nothing after it can be
lost: it is refused or right.

HaMLet's manual says nothing of characters above 127, or of escapes above
255, in a constant. Of the lexical analysis it notes one deviation, that
vertical tab and carriage return are formatting characters too, and its
"Limitations" are about parsing and the Basis Library.

## The fix

`fix.diff`, against `37275b9`. Rune's patch leaves both files as they
are, so it applies to Rune's build as well.

* **`lib/LibrarySVal.sml`:** `stringFromString` scans the constant with
  `String.scan` and takes the result only if nothing is left over; else
  it raises `Overflow`, as when nothing converts. A constant with an
  escape above 255 anywhere is then refused with "special constant out of
  range". This part alone ends the silent change.
* **`parse/Lexer.lex`:** a printable character is one from 33 to 126 but
  `"` and `\`, as in Section 2.2. A raw byte above 126 in a string or a
  character constant is then a lexical error, "invalid string" at its
  opening quote, as a raw TAB or DEL is now.

`parse/Lexer.lex.sml` is made from `parse/Lexer.lex` by ML-Lex and is
checked in; it must be made again, and the diff leaves it out. The
Makefile's rule runs `ml-lex`. With MLton's `mllex`, the start position
must then be set as in the file checked in:
`val yygone0= YYPosInt.fromInt 1`, where `mllex` writes `~1`. The
Makefile's rule for MLton that should do this looks for another form of
the line, and its test `[ "${SYSTEM}" == "mlton" ]` fails under a
`/bin/sh` that is not bash.

Tested, with HaMLet at `37275b9`, Rune's patch and `fix.diff`,
`parse/Lexer.lex.sml` made again by MLton's `mllex` as above, and `make
with-mlton` with MLton 20241230:

* `run.sh` gives

  ```
  bug           bug.sml:6.8-6.9: invalid string
  bug-utf8      bug-utf8.sml:7.14-7.15: invalid string
  bug-cases     bug-cases.sml:6.21-6.22: invalid string
  bug-escape    bug-escape.sml:8.14-8.24: special constant out of range
  bug-equal     bug-equal.sml:4.31-4.32: invalid string
  refused-first refused-first.sml:2.8-2.9: invalid string
  refused-char  refused-char.sml:2.9-2.10: invalid string
  ok-escape     size=4 bytes=99 97 102 233
  ```

* With the `lib/LibrarySVal.sml` part alone (the lexer as it is), every
  program but `ok-escape.sml` is refused with "special constant out of
  range", and `ok-escape.sml` prints the same.
* The 34 programs of HaMLet's `test` directory give the same output with
  and without the fix. So do a constant that is only a gap (`"\ \"`,
  empty), one that ends in a gap, a gap across CR LF, `"\u00E9"`, a raw
  TAB and a raw DEL in a string (refused, at the same position), and
  comments that hold `é`, the byte E9 and U+202E.

## How Rune met it

The probes of Appendix E of `docs/plans/utf8.md` (E2) compare how the
lexers of Rune and six other systems take each kind of character.
Probes 16a (a Latin-1 E9 in a string), 17b (U+202E) and 21b (`e` and
U+0301) showed HaMLet alone running the program with a shorter string;
probes 1, 20 and 21a, where the character comes first in its constant,
showed it refusing with "special constant out of range".

It breaks nothing in Rune. On the branch `hamlet`, HaMLet interprets
Rune's compiler, and no file of its `src` or `lib` holds a byte above 127
or an escape above 255. On `master` and `utf8` there is no such escape in
`src` and `lib` either, and the only bytes above 127 are in comments.

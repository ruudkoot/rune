# MLKit 4.7.25: a raw TAB in a string constant is accepted, and becomes one to eight spaces

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9, Poly/ML 5.9.2, Moscow ML 2.10.1 and HaMLet 2.0.1) does this.** The lexer accepts a program that the Definition rejects, and gives its string another value; Poly/ML, SML/NJ, MLton, Moscow ML and HaMLet refuse the program.

## Status: not reported upstream

This has not been sent to MLKit. MLKit's `master` at `f2b3493`
(2026-10-14) has the same `src/Parsing/LexBasics.sml` and
`src/Parsing/Topdec.lex` as the tags `v4.7.25` and `v4.7.23`, so the bug
is still there.

A search of MLKit's issues and pull requests, their titles, texts and
comments, up to #247 of 2026-10-16, found no report of it (2026-10-19).
The words searched for were "tab", "tabs", "tab character", "untabify",
"spaces", "string literal", "string constant", "character constant",
"lexer", "lex", "non-printing", "unprintable", "control character",
"whitespace", "LexBasics" and "Topdec.lex".

**MLKit 4.7.23 is the same:** `run.sh` gives the same output with it.

## Summary

* **The trigger:** a raw TAB (character 9) between the quotes of a string
  constant, or of a character constant `#"..."`.
* **What goes wrong:** MLKit compiles the program, without a warning, and
  the TAB becomes spaces up to the next column that is a multiple of 8,
  counted from 0.
  * `val s = "a<TAB>b"` gives `s` eight characters, `a`, six spaces and
    `b` (`bug.sml`).
  * The same TAB at another column becomes from one to eight spaces
    (`bug-columns.sml`).
  * In a character constant, the TAB is `#" "` where it stands one column
    before a multiple of 8 (`bug-char.sml`). Elsewhere the constant is
    refused with "string must have length 1", although it holds one
    character (`bug-char-length.sml`).
* **Required behaviour:** the
  [Definition of Standard ML (Revised)](https://smlfamily.github.io/sml97-defn.pdf),
  Section 2.2, makes a string constant "a sequence, between quotes, of
  zero or more printable characters (i.e., numbered 33-126), spaces or
  escape sequences", and writes a TAB as the escape `\t`. A raw TAB is none
  of these, so the program must be rejected. A character constant is `#s`
  with `s` a string constant, so the same holds there. Poly/ML 5.9.2,
  SML/NJ 110.99.9, MLton 20241230, Moscow ML 2.10.1 and HaMLet 2.0.1 refuse
  `bug.sml` and `bug-char.sml`: "unprintable character \t found in
  string", "illegal non-printing character in string", "Illegal character
  in text constant", "invalid character in string" and "invalid string".

## Environment

* **MLKit:** v4.7.25, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.25 (v4.7.25 -
  2026-10-09T23:27:32+02:00) [X64 Backend]"), as Rune's
  `scripts/fetch-hosts.sh` installs it. Also v4.7.23, the same release
  file of that version.
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2.
* **Basis Library: MLKit's own.** Every program is built from an `.mlb`
  file that lists `$(SML_LIB)/basis/basis.mlb` and the program, with
  `mlkit -o prog prog.mlb`. Nothing of Rune is involved.

## What happens

`bug.sml`, where `<TAB>` stands for the one byte 9 that the file holds:

```sml
(* The Definition of Standard ML (Revised), Section 2.2: a string constant
   holds printable characters, spaces and escape sequences; a TAB is
   written \t. The literal below holds a raw TAB, so the program
   must be rejected. *)
fun bytes s = String.concatWith " " (map (Int.toString o Char.ord) (explode s))
val s = "a<TAB>b"
val () = print ("size=" ^ Int.toString (size s) ^ " bytes=" ^ bytes s ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
size=8 bytes=97 32 32 32 32 32 32 98
```

The TAB is at column 10, counted from 0, and the next multiple of 8 is 16:
six spaces. In MLKit's REPL the columns are counted from the start of its
prompt `. `, so the same line gives four spaces there (`size s` is 6).
Poly/ML 5.9.2 says:

```
bug.sml:6: error: unprintable character \t found in string
```

`run.sh` builds all the programs
(`MLKIT=/path/to/mlkit sh run.sh`):

```
MLKit v4.7.25 (v4.7.25 - 2026-10-09T23:27:32+02:00) [X64 Backend]
bug              size=8 bytes=97 32 32 32 32 32 32 98
bug-columns      TAB at column 20: 4 spaces
                 TAB at column 21: 3 spaces
                 TAB at column 22: 2 spaces
                 TAB at column 23: 1 space
                 TAB at column 24: 8 spaces
                 TAB at column 25: 7 spaces
                 TAB at column 26: 6 spaces
                 TAB at column 27: 5 spaces
                 TAB at column 28: 4 spaces
bug-char         32
bug-char-length  compiler: string must have length 1
related-controls 97 127 98 27 99
ok-escape        97 9 98
ok-gap           97 98
```

`bug-char-length.sml` is refused with the TAB already gone from the line
that the message shows:

```
bug-char-length.sml, line 3, column 16:
  val tab = #"    "
                  ^
string must have length 1
```

`ok-escape.sml` writes the TAB as `\t`, and `ok-gap.sml` puts a raw TAB in
a gap `\...\`, where the Definition allows it ("formatting characters"):
both are right, and stay right with the fix below.

**Related: other control characters are kept as they are.**
`related-controls.sml` has a raw DEL (127) and a raw ESC (27) in a string,
which the Definition does not allow either, and MLKit keeps both. SML/NJ
also keeps a raw DEL, but refuses characters 0 to 31; Poly/ML, MLton,
Moscow ML and HaMLet refuse both. This changes no meaning, so it is
not the bug reported here, but the fix below refuses them too.

## The cause

MLKit reads a source file into a list of lines, and expands every TAB of
every line before the lexer sees it, so that the columns of its messages
count a TAB as reaching the next multiple of 8. `src/Parsing/LexBasics.sml`,
lines 39-51:

```sml
    local
      fun spaces (n,a) = if n<=0 then a
                         else spaces(n-1,#" "::a)

      fun untabifyL (col, #"\t" :: rest) =
        let val gap = 8 - col mod 8
        in spaces (gap, untabifyL(col + gap, rest))
        end
        | untabifyL (col, x :: rest) = x :: untabifyL(col + 1, rest)
        | untabifyL (_, nil) = nil
    in
      fun untabify indent line = implode(untabifyL(indent, explode line))
    end
```

`fileToSourceText` (line 88) and `stringToSourceText` (line 74) apply it to
each line (`val lines = map (untabify 0) (process stream)`), and the
lexer reads those lines; `lexFromStdIn`, for the REPL, does the same after
the prompt (lines 211-214). The comment above `SourceText` says why:
"Oh: we must remove tabs in here".

Between tokens and in a gap a TAB is white space, and spaces do as well.
Inside a string constant they do not, and the lexer never sees the TAB to
refuse it. Had it seen it, it would have kept it: the rule for the
characters of a string, `src/Parsing/Topdec.lex` line 212,

```
<S>[^"\\\n]*            => (LexUtils.addChars yytext arg; continue());
```

takes every character but `"`, `\` and newline, which is why DEL and ESC
are kept. A character constant `#"..."` is lexed as `#` and a string, and
the string's length is checked later, which gives "string must have
length 1".

## The fix

`fix.diff`, against `v4.7.25`; it applies to `master` too, which has the
same two files:

* **`LexBasics.sml`:** keep the lines as they are read, TABs included, for
  the lexer. Expand the TABs only where a line is shown or a column is
  given: `getLine` returns the expanded line, and the column of a position
  is the column in the expanded line (`untabbedColumn`). Messages and
  their underlining stay as they are. In the REPL the expansion still
  starts after the prompt.
* **`Topdec.lex`:** inside a string, a character from 0 to 31 other than
  newline, or 127, is an error, "control character in string (use an
  escape, such as \t)". A newline is still "unclosed string". Characters
  128 to 255 are still taken, as now.

`Topdec.lex.sml` is generated from `Topdec.lex` by `mlkit-mllex` (the rule
in `src/Makefile.in`), and `make` makes it again, since the patched
`Topdec.lex` is newer; the diff leaves it out.

The fix also changes the `quotation` extension (off by default): a TAB in
a quotation is kept as a TAB, where it was spaces.

MLKit was not built with the patch, so it has not been run. What was
checked:
* `mlkit-mllex`, built from the sources of `v4.7.25`, accepts the
  patched `Topdec.lex` and makes `Topdec.lex.sml` from it.
* The patched `LexBasics.sml` compiles with Poly/ML 5.9.2, with stand-ins
  for `Report`, `PrettyPrint` and `Crash`. It was given a file with TABs
  between tokens and in a comment. Its lexing function returns the lines
  with their TABs. For every token, its position gives the same line,
  column and shown line as the original's does for that token in the
  expanded text, and so does the end of the file.

The REPL's path (`lexFromStdIn`) and the new rule of `Topdec.lex` were
checked only by reading the code.

## How Rune met it

The probes of Appendix E of `docs/plans/utf8.md` (E2) compare how the
lexers of Rune and six other systems take each kind of character; probe
6, a raw TAB in a string, showed MLKit alone taking it, as six spaces.

It breaks nothing in Rune. Of Rune's SML files, only three hold a raw
control character in a string constant: `tests/errors/err.lex_control_in_string.sml`
(a TAB), `err.lex_del_in_string.sml` and `err.lex_del_in_char.sml` (a
DEL). They test Rune's own lexer, which refuses them ("control character
U+0009 in string literal (write it as \t)"), and MLKit never reads them.

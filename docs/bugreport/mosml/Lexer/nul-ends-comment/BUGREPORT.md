# Moscow ML 2.10.1: the lexer takes a character 0 (NUL) for the end of the input, so a comment that holds one is "not terminated"

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9, Poly/ML 5.9.2, MLKit 4.7.25 and HaMLet 2.0.1) does this.** All five compile `bug.sml`, which prints `ok`, and refuse a character 0 between two declarations, where Moscow ML ends the program without a word.

## Status

Not reported upstream from here. `master` at `13c581a` (2021-07-02, the
newest commit on 2026-10-19) has the same `src/compiler/Lexer.lex`,
`src/mosmllib/Lexing.sml`, `src/mosmllib/Lexing.sig`,
`src/lex/Grammar.grm` and `src/runtime/lexing.c`, byte for byte; so has
the branch `devel` (`854993e`, 2021-07-14) for `Lexer.lex`, `Lexing.sml`
and `Grammar.grm`, the three that were compared there.

A search of kfl/mosml's issues and pull requests on 2026-10-19, all 80 of
them up to #81 of 2026-02-09, their texts and comments, found no report
of it. The open pull request
[kfl/mosml#74](https://github.com/kfl/mosml/pull/74), "Changes for UTF8
character representation within string literals" (2024-01-26), changes
the rule `String` of `Lexer.lex` and keeps its `` (eof | `\^Z`) ``; it
does not touch `Comment` or `Lexing`.

## Summary

* **The trigger:** a character 0 (NUL) in the source text, as a byte of
  the file: in a comment, in a string constant, or between items. The
  escape `\000` in a string is not affected.
* **What goes wrong:** Moscow ML's lexer takes the character for the end
  of the input.
  * **In a comment:** "Lexical error: comment not terminated."
    (`bug.sml`).
  * **In a string constant:** "Lexical error: string not terminated."
    (`bug-string.sml`), though the string ends with its quote. An error
    is right, the message is not: for the characters 1 to 25, 127 and
    255 Moscow ML says "invalid character in string".
  * **Between two declarations:** the program ends there, without a
    message. `mosmlc` compiles the declarations before the character,
    with exit status 0, and the program runs them and not the rest
    (`bug-between.sml`). Inside a declaration the parser meets the end
    too early: "Syntax error.".
  * It is the same in the batch compiler `mosmlc` and in the toplevel
    `mosml`, for a file named on the command line, a file read by `use`
    and standard input, where a character 0 ends the session.
* **Required behaviour:** the
  [Definition of Standard ML (Revised)](https://smlfamily.github.io/sml97-defn.pdf),
  Section 2.3, "Comments": "A comment is any character sequence within
  comment brackets (* *) in which comment brackets are properly nested."
  The characters are those of Section 2.2: "We assume an underlying
  alphabet of N characters (N ≥ 256), numbered 0 to N − 1, which agrees
  with the ASCII character set on the characters numbered 0 to 127." So a
  comment may hold the character 0. A string constant may not hold it
  raw (Section 2.2: "A string constant is a sequence, between quotes
  ("), of zero or more printable characters (i.e., numbered 33–126),
  spaces or escape sequences."), and between items it is not one of
  Moscow ML's formatting characters (space, tab, newline, carriage return
  and form feed, `Lexer.lex`, line 233); there an error is right, but
  not "not terminated", and not a silent end of the program.

## Environment

* **Moscow ML:** 2.10.1 (its toplevel says "Moscow ML version 2.10"),
  built from the release's tag `ver-2.10.1` by Rune's
  `scripts/fetch-hosts.sh` (`make world` and `make install` in `src`),
  its `IntInf` linked against GMP 6.3.0.
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2, gcc 13.3.
* **Basis Library: Moscow ML's own.** The programs are compiled with
  `mosmlc -o bug bug.sml` and loaded into the toplevel with
  `mosml -quietdec bug.sml`. Nothing of Rune is involved.

## The programs

Each program holds one character 0, shown here as `^@`, as `cat -v` and
Moscow ML's messages show it (`od -c` shows it as `\0`).

`bug.sml`, with the character 0 between `a` and `b` on line 7:

```sml
(* The Definition of Standard ML (Revised), Section 2.3: "A comment is any
   character sequence within comment brackets (* *) in which comment
   brackets are properly nested."  Section 2.2: "We assume an underlying
   alphabet of N characters ..., numbered 0 to N - 1".
   The comment on the next line holds the character 0, between a and b.
   Expected output: ok *)
(* a^@b *)
val () = print "ok\n"
```

Moscow ML refuses it, with exit status 2:

```
$ mosmlc -o bug bug.sml
File "bug.sml", line 7, characters 0-5:
! (* a^@b *)
! ^^^^^
! Lexical error: comment not terminated.
```

The toplevel gives the same message, for `mosml bug.sml` and for
`use "bug.sml";`. MLton, SML/NJ, Poly/ML, MLKit and HaMLet print `ok`.

`bug-string.sml` has `val s = "a^@b"` on line 7, a string the Definition
does not allow:

```
$ mosmlc -o bug-string bug-string.sml
File "bug-string.sml", line 7, characters 8-11:
! val s = "a^@b"
!         ^^^
! Lexical error: string not terminated.
```

MLton says "Illegal character in text constant.", SML/NJ "illegal
non-printing character in string", Poly/ML "unprintable character \^@
found in string" and HaMLet "invalid string"; MLKit takes the string, a
fault of its own. With the character 1 in its place, Moscow ML says
"invalid character in string", at characters 10-11, the character.

`bug-between.sml` has a line that holds only the character 0, line 9,
between two declarations:

```sml
val () = print "before the character 0\n"
^@
val () = print "after the character 0\n"
```

```
$ mosmlc -o bug-between bug-between.sml && ./bug-between
before the character 0
```

The exit status of `mosmlc` is 0, and the second declaration is not in
the program. `mosml bug-between.sml` prints the same line, and so does
`use "bug-between.sml";`, after which the toplevel goes on with the
file or input that has the `use`. MLton ("Illegal token."), SML/NJ
("illegal token"), Poly/ML ("unknown character "\^@""), MLKit ("cannot lex
"^@"") and HaMLet ("invalid character `\^@'") refuse the program. Moscow
ML refuses the character 1 there with "ill-formed token".

`run.sh` compiles and runs each program with `mosmlc` and loads it into
`mosml` (`MOSMLC=/path/to/mosmlc sh run.sh`):

```
Moscow ML version 2.10
bug          mosmlc: exit 2, error: Lexical error: comment not terminated.
bug          mosml:  error: Lexical error: comment not terminated.
bug-string   mosmlc: exit 2, error: Lexical error: string not terminated.
bug-string   mosml:  error: Lexical error: string not terminated.
bug-between  mosmlc: compiles; the program prints: before the character 0
bug-between  mosml:  prints: before the character 0
```

Elsewhere, compiled by `mosmlc` one by one:

| Where the character 0 is | Moscow ML 2.10.1 |
|---|---|
| in a comment, also a nested one, or one of 9,000 bytes holding 3,000 of them | comment not terminated |
| in a string constant | string not terminated |
| in the gap of a string, `"a\ ^@ \b"` | string not terminated (with the character 1: "ill-formed escape sequence") |
| between two declarations, or at the end of the last one (`val y = x^@`) | the program ends there, with no message |
| as the last byte of the file, after the last declaration | no message, the program as without it |
| inside a declaration, `val x =^@ 1` | Syntax error. |
| in a quotation or an antiquotation (`mosmlc -quotation`) | quotation not terminated, antiquotation not terminated |
| on standard input to the toplevel, between declarations | the session ends: the declarations after it are not read |

## The cause

Moscow ML's lexer generator, `mosmllex`, comes from Caml Light's
`camllex`, and marks the end of the input with a character 0 in the
lexer buffer. Its pattern `eof` is that character
(`src/lex/Grammar.grm`, lines 90-91):

```
  | Teof
        { Characters [#"\000"] }
```

and its wildcard `_` is every character but that one
(`src/lex/Gram_aux.sml`, line 26):

```sml
val all_chars = char_class #"\001" #"\255";
```

The run-time library puts the character in the buffer when the input
ends: `lexRefill` in `src/mosmllib/Lexing.sml` (lines 40-56), when the
function that reads the input returns 0,

```sml
fun lexRefill readFun lexbuf =
  let
    val read = readFun charBuffer 1024
    val n = if read > 0 then read
            else (set_nth_char_ lexAuxBuffer 0 0; 1)
```

and `createLexerString` appends `"\000"` to its string (lines 64-67).
A character 0 of the input reaches the lexer as the same character. The
documentation says only that `eof` matches the end:
`src/mosmllib/Lexing.sig` ("A return value of 0 means end of input.")
and the manual, `src/doc/manual.tex`, lines 3130-3132 ("eof: Match the
end of the lexer input.").

Every rule of `src/compiler/Lexer.lex` treats `eof` as the end of the
input. In a comment (lines 347-356):

```
and Comment = parse
    "(*"
      { (incr comment_depth; Comment lexbuf) }
  | "*)"
      { (decr comment_depth;
         if !comment_depth > 0 then Comment lexbuf else ()) }
  | (eof | `\^Z`)
      { notTerminated "comment" lexbuf }
  | _
      { Comment lexbuf }
```

which `mosmllex` turns into this state, where `#"\^@"` is the
character 0 and `action_33` is `notTerminated "comment" lexbuf`:

```sml
and state_5 lexbuf = (
 let val currChar = getNextChar lexbuf in
 case currChar of
    #"*" => state_72 lexbuf
 |  #"(" => state_71 lexbuf
 |  #"\^Z" => action_33 lexbuf
 |  #"\^@" => action_33 lexbuf
 |  _ => action_34 lexbuf
 end)
```

The rule `String` has `` | (eof | `\^Z`) { notTerminated "string" lexbuf } ``
(lines 389-390), before its rule for control characters,
`` [`\^A`-`\^Z` `\127` `\255`] ``, which does not have the character 0.
Between items, the rule `TokenN` returns the token `EOF` (line 310:
`` | (eof | `\^Z`) { EOF } ``), and the grammar ends a file there
(`src/compiler/Parser.grm`, line 364: `TopDecFile : KWDec_seq EOF`; the
toplevel's phrases end in `EOPh`, a `SEMICOLON` or `EOF`, lines 342-345).
After a complete declaration the parser accepts the end, and the rest of
the file is never read; inside one, `EOF` is a syntax error.

The same rules take the character 26 (Ctrl-Z, `\^Z`, the end-of-file
mark of MS-DOS) for the end of the input, on purpose: a comment or a
string that holds it is "not terminated" too, and one between
declarations ends the program. MLton, SML/NJ, Poly/ML, MLKit and HaMLet print `ok` for a
comment that holds it. That is a choice of Moscow ML's, and not the
subject here; the fix below keeps it.

## The fix

Let the lexer buffer remember where the input ended, and let the rules
of `eof` in `Lexer.lex` ask whether the character 0 they matched is that
end or a character of the input (`fix.patch`):

```diff
--- a/src/mosmllib/Lexing.sig
+++ b/src/mosmllib/Lexing.sig
@@ -12,6 +12,7 @@
 val getLexemeChar     : lexbuf -> int -> char
 val getLexemeStart    : lexbuf -> int
 val getLexemeEnd      : lexbuf -> int
+val atEndOfInput      : lexbuf -> bool
 
 (* For internal use in generated lexers: *)
 
@@ -83,4 +84,10 @@
    [getLexemeEnd lexbuf] returns the end position, plus one, of the
    matched string (in the input stream).  The first character in the
    stream has position 0.  
+
+   [atEndOfInput lexbuf] is true if the matched string starts at the
+   end of the input.  The pattern eof matches the character #"\000",
+   with which the lexer buffer marks the end of the input, so an
+   action for eof can use atEndOfInput to tell the end of the input
+   from a character #"\000" in the input.
 *)
--- a/src/mosmllib/Lexing.sml
+++ b/src/mosmllib/Lexing.sml
@@ -9,7 +9,8 @@
   (* lexStartPos *)    int *
   (* lexCurrPos *)     int *
   (* lexLastPos *)     int *
-  (* lexLastAction *)  (lexbuf -> obj)
+  (* lexLastAction *)  (lexbuf -> obj) *
+  (* lexEndPos *)      int        (* where the input ends; ~1 if not known *)
 ;
 
 prim_val getRefillBuff    : lexbuf -> (lexbuf -> unit) = 1 "field0";
@@ -19,6 +20,7 @@
 prim_val getLexCurrPos    : lexbuf -> int              = 1 "field4";
 prim_val getLexLastPos    : lexbuf -> int              = 1 "field5";
 prim_val getLexLastAction : lexbuf -> (lexbuf -> obj)  = 1 "field6";
+prim_val getLexEndPos     : lexbuf -> int              = 1 "field7";
 
 prim_val setRefillBuff    : lexbuf -> (lexbuf -> unit) -> unit = 2 "setfield0";
 prim_val setLexBuffer     : lexbuf -> string -> unit           = 2 "setfield1";
@@ -27,6 +29,7 @@
 prim_val setLexCurrPos    : lexbuf -> int -> unit              = 2 "setfield4";
 prim_val setLexLastPos    : lexbuf -> int -> unit              = 2 "setfield5";
 prim_val setLexLastAction : lexbuf -> (lexbuf -> obj) -> unit  = 2 "setfield6";
+prim_val setLexEndPos     : lexbuf -> int -> unit           = 2 "setfield7";
 
 prim_val create_string_ : int -> string                 = 1 "create_string";
 prim_val nth_char_      : string -> int -> char         = 2 "get_nth_char";
@@ -49,6 +52,11 @@
     setLexCurrPos lexbuf (getLexCurrPos lexbuf - n);
     setLexStartPos lexbuf (getLexStartPos lexbuf - n);
     setLexLastPos lexbuf (getLexLastPos lexbuf - n);
+    (* At the end of the input the buffer gets a character #"\000", which
+       the pattern eof matches; remember where it is, so that it can be
+       told from a #"\000" in the input. *)
+    if read > 0 orelse getLexEndPos lexbuf >= 0 then ()
+    else setLexEndPos lexbuf (getLexAbsPos lexbuf + 2048 - n);
     if getLexStartPos lexbuf < 0 then
       raise Fail "lexer: token too long"
     else ()
@@ -58,12 +66,12 @@
 fun dummyAction x = raise Fail "lexer: illegal symbol in input";
 
 fun createLexer f = LEXBUF
-  (lexRefill f, create_string_ 2048, ~2048, 2048, 2048, 2048, dummyAction)
+  (lexRefill f, create_string_ 2048, ~2048, 2048, 2048, 2048, dummyAction, ~1)
 ;
 
 fun createLexerString s = LEXBUF
   ( fn lexbuf => setLexCurrPos lexbuf (getLexCurrPos lexbuf - 1),
-    s ^ "\000", 0, 0, 0, 0, dummyAction )
+    s ^ "\000", 0, 0, 0, 0, dummyAction, size s )
 ;
 
 fun getLexeme lexbuf =
@@ -92,4 +100,9 @@
   getLexAbsPos lexbuf + getLexCurrPos lexbuf
 ;
 
+fun atEndOfInput lexbuf =
+  let val endPos = getLexEndPos lexbuf
+  in endPos >= 0 andalso getLexemeStart lexbuf >= endPos end
+;
+
 prim_val getNextChar : lexbuf -> char = 1 "get_next_char";
--- a/src/compiler/Lexer.lex
+++ b/src/compiler/Lexer.lex
@@ -173,6 +173,13 @@
   raise LexicalError(msg, getLexemeStart lexbuf, getLexemeEnd lexbuf)
 )
 
+(* The pattern eof matches the character #"\000", which marks the end
+   of the input; isNul tells a #"\000" of the input from the end.  The
+   Definition, Section 2.3, allows any character in a comment. *)
+
+fun isNul lexbuf =
+  getLexemeChar lexbuf 0 = #"\000" andalso not (atEndOfInput lexbuf)
+
 fun constTooLarge msg lexbuf =
 (
   resetLexerState();
@@ -307,7 +314,8 @@
           RPAREN
       }
   | ";"         { SEMICOLON }
-  | (eof | `\^Z`) { EOF }
+  | (eof | `\^Z`)
+      { if isNul lexbuf then lexError "ill-formed token" lexbuf else EOF }
   | ""          { if !quotation then TokenIdQ lexbuf else TokenId lexbuf }
 
 and TokenId = parse
@@ -351,7 +359,8 @@
       { (decr comment_depth;
          if !comment_depth > 0 then Comment lexbuf else ()) }
   | (eof | `\^Z`)
-      { notTerminated "comment" lexbuf }
+      { if isNul lexbuf then Comment lexbuf
+        else notTerminated "comment" lexbuf }
   | _
       { Comment lexbuf }
 
@@ -387,7 +396,9 @@
   | `\\`
       { skipString "ill-formed escape sequence" SkipString lexbuf }
   | (eof | `\^Z`)
-      { notTerminated "string" lexbuf }
+      { if isNul lexbuf then
+          skipString "invalid character in string" SkipString lexbuf
+        else notTerminated "string" lexbuf }
   | [`\n` `\r`]
       { skipString "newline not permitted in string" SkipString lexbuf }
   | [`\^A`-`\^Z` `\127` `\255`]
@@ -404,7 +415,8 @@
   | `\\` [` ` `\t` `\n` `\r`]+ `\\`
       { SkipString lexbuf }
   | (eof | `\^Z`)
-      { notTerminated "string" lexbuf }
+      { if isNul lexbuf then SkipString lexbuf
+        else notTerminated "string" lexbuf }
   | _
       { SkipString lexbuf }
 
@@ -419,8 +431,11 @@
       { (store_string_char(getLexemeChar lexbuf 0);
          Quotation lexbuf) }
   | (eof | `\^Z`)
-      { lexingMode := NORMALlm;
-        notTerminated "quotation" lexbuf
+      { if isNul lexbuf then
+          skipString "invalid character in quotation" SkipQuotation lexbuf
+        else
+          (lexingMode := NORMALlm;
+           notTerminated "quotation" lexbuf)
       }
   | [`\^A`-`\^Z` `\127` `\255`]
       { skipString "invalid character in quotation" SkipQuotation lexbuf }
@@ -432,8 +447,10 @@
     "`"
       { lexingMode := NORMALlm }
   | (eof | `\^Z`)
-      { lexingMode := NORMALlm;
-        notTerminated "quotation" lexbuf
+      { if isNul lexbuf then SkipQuotation lexbuf
+        else
+          (lexingMode := NORMALlm;
+           notTerminated "quotation" lexbuf)
       }
   | _
       { SkipQuotation lexbuf }
@@ -454,8 +471,11 @@
         lexError "antiquotation is missing" lexbuf
       }
   | (eof | `\^Z`)
-      { lexingMode := NORMALlm;
-        notTerminated "antiquotation" lexbuf
+      { if isNul lexbuf then
+          skipString "ill-formed antiquotation" SkipQuotation lexbuf
+        else
+          (lexingMode := NORMALlm;
+           notTerminated "antiquotation" lexbuf)
       }
   | _
       {
```

The end of the input is where `lexRefill` writes its character 0, the
first time the reading function returns 0: at position
`getLexAbsPos lexbuf + 2048 - n` once the buffer has been shifted. For a
lexer of a string it is the string's size. A character 0 of the input
lies before that position, or comes before the end is known (the
position is then ~1). With the patch a character 0 is, in a comment, a
character of the comment; in a string, "invalid character in string",
as for the characters 1 to 25; between items, "ill-formed token", as for
the character 1; in a quotation or antiquotation, the messages of the
character 1 there. The character 26 is left as it was.

`lexbuf` is an abstract type in `Lexing.sig`, so its eighth field
changes no program; the runtime's `get_next_char`
(`src/runtime/lexing.c`) reads only the first five. Other lexers made by
`mosmllex` (its own, and those of Moscow ML's users) still take a
character 0 for `eof`, but can now call `atEndOfInput`. A fuller fix
would give `eof` a symbol of its own in `mosmllex`, apart from the 256
characters, as OCaml's `ocamllex` does; that changes the generator and
what every lexer made with it matches.

Tested: Moscow ML 2.10.1 with this patch was built in a copy of the
release's tree (`make world` and `make install` into a directory of that
copy). With it:
* `run.sh` gives:

  ```
  Moscow ML version 2.10
  bug          mosmlc: compiles; the program prints: ok
  bug          mosml:  prints: ok
  bug-string   mosmlc: exit 2, error: Lexical error: invalid character in string.
  bug-string   mosml:  error: Lexical error: invalid character in string.
  bug-between  mosmlc: exit 2, error: Lexical error: ill-formed token.
  bug-between  mosml:  error: Lexical error: ill-formed token.
  ```

  The two errors are at the character 0: `bug-string.sml`, line 7,
  characters 10-11, and `bug-between.sml`, line 9, characters 0-1;
* `bug.sml` prints `ok` when it is read by `use`, and when it is the
  toplevel's standard input; there `bug-between.sml` stops at
  "ill-formed token" as with the character 1;
* a comment prints `ok` with the character 0 at any of the byte offsets
  5, 1022-1025, 2046-2049, 3071, 3072, 4095 and 4096 of the file, around
  the ends of the reads of 1024 bytes and of the buffer of 2048, with
  3,000 of them, and in a nested comment;
* "ill-formed token" for `val x =^@ 1`, for `val y = x^@` and `1.5^@`
  (the character after a token) and for the character 0 as the last byte
  of the file; "ill-formed escape sequence" in the gap of a string, as
  for the character 1; "invalid character in quotation" and "ill-formed
  antiquotation" with `-quotation`;
* the end of the input is still the end: a comment not closed at the end
  of the file is "comment not terminated", with a character 0 in it or
  not, and `"a\000b"` is still a string of size 3;
* with the patched compiler, `make current` in `src/mosmllib` compiles
  Moscow ML's library again (83 units); Moscow ML's own tests (`make
  all` in `src/test`) give the same `result` as unpatched but for the
  times measured, and the library's tests (`test.sml` in
  `src/mosmllib/test`) the same output, which stops, patched and
  unpatched, at a type error of its own in `bytechar.sml`.

`master` was not built.

## How Rune met it

It was not met in Rune's code. It turned up in a survey of source text
made for Rune's UTF-8 work (`docs/plans/utf8.md`, *Bugs found in other
compilers*), which ran the same small programs on Rune, MLton, SML/NJ,
Poly/ML, MLKit, HaMLet and Moscow ML, the last with
`mosml -quietdec pre.sml p.sml`; its program 8a, a comment that holds a
character 0 and then a declaration that prints `ok`, is `bug.sml`. No
source of Rune has a character 0 in a comment. The three that have one
between tokens, `tests/errors/err.lex_space_nul*.sml`, are tests of
Rune's own message for it, which Moscow ML does not compile.

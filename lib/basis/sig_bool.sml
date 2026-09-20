(* Booleans: negation, and conversion to and from text.

   The conditional `if`, and `andalso` and `orelse`, which evaluate their
   second
   operand only when they must, are part of the language; `not` is also in the
   top-level environment.

   Area: Text and characters

   See also: `STRING_CVT` *)
signature BOOL =
sig
  (* The type of truth values, with the constructors `false` and `true`. It
     is the top-level `bool`.

     Erratum: `BOOL/bool-spec`. The specification writes `datatype bool =
     false | true`. The Definition (Section 2.9) does not allow `true` and
     `false` to be specified, so the signature replicates the top-level
     datatype instead; the meaning is the same. *)
  datatype bool = datatype bool

  (* `not b` is the negation of `b`. *)
  val not : bool -> bool

  (* `toString b` is `"true"` or `"false"`. *)
  val toString : bool -> string

  (* `scan getc strm` reads a boolean from the character stream `strm`, which
     `getc` reads.

     It skips initial white space and then takes the word `true` or `false`,
     in any mixture of upper and lower case. The answer is `SOME (b, rest)`,
     with `rest` the stream after the word, or `NONE` when neither word is
     there, in which case nothing has been consumed. What follows the word
     stays in the stream, also when it is a letter: `"truer"` scans as `true`
     and leaves `"r"`.

     Reading: `Bool.scan/wsx-*`. "Initial whitespace" is what `Char.isSpace`
     accepts, as for `StringCvt.skipWS`: the space, and the characters `\t`,
     `\n`, `\v`, `\f` and `\r`. *)
  val scan : (char, 'a) StringCvt.reader -> (bool, 'a) StringCvt.reader

  (* `fromString s` is the boolean that `s` begins with, read as `scan` reads
     it, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Reading: `Bool.fromString/none-not-whitespace-*`. The characters whose
     codes are next to those of the white space characters (0, 8, 14, 31, 33,
     95 and 127) are not white space: a string that begins with one of them
     gives `NONE`. *)
  val fromString : string -> bool option
end

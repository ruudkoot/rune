(* The types and helpers of the conversions between values and text: the
   formats of `fmt`, the readers of `scan`.

   Every `scan` function of the library reads from a functional character
   stream: a value of any type `'b` together with a reader, a function that
   gives the next character and the rest of the stream, or `NONE` at the end.
   A scanner takes a reader of characters and gives a reader of values, so it
   works alike on strings, lists of characters, substrings and input streams,
   and a program can build scanners of its own out of those of the library and
   the helpers below. Nothing is consumed by a scan that fails: the caller
   still has the stream it passed.

   Area: Text and characters

   See also: `CHAR`, `STRING`, `SUBSTRING`, `TEXT_IO` *)
signature STRING_CVT =
sig
  (* ---- Formats ---- *)

  (* The base in which `Int.fmt`, `Word.fmt` and their `scan` functions write
     and read a number. *)
  datatype radix
    = BIN   (* base 2 *)
    | OCT   (* base 8 *)
    | DEC   (* base 10 *)
      (* base 16; the digits above 9 are written `A` to `F` and read in either
         case *)
    | HEX

  (* The notation in which `Real.fmt` writes a real number.

     The argument is a number of digits; `NONE` asks for the default.

     Reading: `StringCvt.SCI/carries-negative`. A constructor carries any
     `int option`, also one that no format accepts, such as `SCI (SOME ~1)`:
     `Size` is raised by `fmt`, not by the constructor. *)
  datatype realfmt
      (* scientific notation, `[~]d.dddE[~]dd`, with that many digits after the
         point; 6 by default *)
    = SCI of int option
      (* fixed-point notation, `[~]ddd.ddd`, with that many digits after the
         point; 6 by default *)
    | FIX of int option
      (* the shorter of `SCI` and `FIX`, with at most that many significant
         digits; 12 by default *)
    | GEN of int option
      (* every digit needed to read the same real back *)
    | EXACT

  (* ---- Readers ---- *)

  (* A reader of values of type `'a` from a stream of type `'b`: `NONE` at the
     end of the stream, otherwise the next value and the rest of the stream. *)
  type ('a, 'b) reader = 'b -> ('a * 'b) option

  (* ---- Padding ---- *)

  (* `padLeft c i s` is `s` with enough copies of `c` on its left to make it
     `i` characters long.

     A string that has `i` characters or more is returned as it is, also for a
     negative `i`.

     Raises: `Size` if `i` is larger than `String.maxSize` and `s` is shorter
     than `i`.

     Example: `padLeft #"0" 5 "42" = "00042"`

     Reading: `StringCvt.padLeft/width-minInt`. For the smallest `int` the
     difference `i - size s` does not exist as an `int`; `s` is returned all
     the same, and `Overflow` is not raised. *)
  val padLeft : char -> int -> string -> string

  (* `padRight c i s` is `s` with enough copies of `c` on its right to make it
     `i` characters long.

     A string that has `i` characters or more is returned as it is.

     Raises: `Size` if `i` is larger than `String.maxSize` and `s` is shorter
     than `i`.

     Example: `padRight #"." 5 "ab" = "ab..."` *)
  val padRight : char -> int -> string -> string

  (* ---- Building scanners ---- *)

  (* `splitl p getc strm` is the string of the characters at the front of
     `strm` that satisfy `p`, and the rest of the stream.

     The rest begins with the first character that does not satisfy `p`.

     Reading: `StringCvt.splitl/reads-no-further-than-first-failing`. "Will
     often use lookahead characters" is taken to mean exactly one: the
     character that stops the scan is read from the source, and nothing after
     it.

     Example: `splitl Char.isDigit List.getItem (explode "12ab") = ("12",
     [#"a", #"b"])` *)
  val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> string * 'a

  (* `takel p getc strm` is the string of the characters at the front of `strm`
     that satisfy `p`.

     Law: `takel p getc strm = #1 (splitl p getc strm)` *)
  val takel : (char -> bool) -> (char, 'a) reader -> 'a -> string

  (* `dropl p getc strm` is `strm` without the characters at its front that
     satisfy `p`.

     Law: `dropl p getc strm = #2 (splitl p getc strm)`

     Example: `implode (dropl Char.isSpace List.getItem (explode "  x")) = "x"` *)
  val dropl : (char -> bool) -> (char, 'a) reader -> 'a -> 'a

  (* `skipWS getc strm` is `strm` without the white space at its front.

     White space is what `Char.isSpace` accepts.

     Law: `skipWS getc strm = dropl Char.isSpace getc strm` *)
  val skipWS : (char, 'a) reader -> 'a -> 'a

  (* ---- Scanning a string ---- *)

  (* The stream that `scanString` makes of a string: a scanner can do nothing
     with it but read it. *)
  type cs

  (* `scanString scan s` applies the scanner `scan` to the characters of `s`,
     from the first.

     The answer is `SOME v` when `scan` reads a value `v`, whatever follows it
     in `s`, and `NONE` when it reads none. This is how every `fromString` of
     the library is made from its `scan`.

     Example: `scanString (Int.scan DEC) "12abc" = SOME 12` *)
  val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option
end

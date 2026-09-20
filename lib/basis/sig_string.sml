(* Strings: immutable sequences of characters, with the operations that take
   them apart, put them together, compare them and write them as the text of
   a string constant.

   A string is indexed from 0 and is of a fixed length, `size s`; there is no
   terminating character, so a string may hold any character, the one with
   code 0 included. Taking a string apart never copies more than it must, but
   every operation that makes one does copy, so building a long string by
   repeated `^` costs time quadratic in the result: collect the pieces in a
   list and `concat` them once.

   The signature is that of `String`, whose characters are of type `char`, and
   of the optional `WideString`, which is why it specifies a type `char` of
   its own. The strings of the library are compared by their characters'
   codes, and that order is what `<`, `compare` and `Substring.compare` use.

   Area: Text and characters

   See also: `CHAR`, `SUBSTRING`, `STRING_CVT`, `TEXT`, `MONO_VECTOR`

   Erratum: `STRING/string-types`. The specification writes the types of
   `toString`, `scan`, `fromString`, `toCString` and `fromCString` with
   `String.string`, because the text of an escape is always of 8-bit
   characters, also for `WideString`. They are kept as written. *)
signature STRING =
sig
  (* ---- Types and bounds ---- *)

  (* The type of strings of these characters.

     Implementation: `String.string/bytes`. `String.string` is the top-level
     `string`, a sequence of 8-bit characters; `WideString.string` is one of
     `WideChar.char`.

     Implementation: `String.string/u-escape-above-255-rejected`. An escape
     `\uXXXX` above 255 in a constant of type `string` or `char` is an error
     when the program is compiled, for the characters have eight bits; at
     `WideString.string` it is a character. *)
  eqtype string

  (* The type of the characters of such a string: `Char.char` for `String`. *)
  eqtype char

  (* The greatest length a string may have.

     Implementation: `String.maxSize/value`. 1073741823, which is 2^30 - 1.

     Pinned by: `String.maxSize/positive`, `String.maxSize/holds-a-long-string`

     Implementation: `String.maxSize/Size-is-not-pinned`. With a bound of 2^30
     - 1 no check of the suite makes a string that is too long: `Size` from
     `^`, `concat`, `implode` and `translate` is raised by the VM when the
     bound is passed, and the suite checks it only on a system whose `maxSize`
     is at most 2^26. The same holds for `StringCvt.padLeft` and `padRight`,
     for `Substring.concat` and `concatWith`, and with `Vector.maxLen` for
     `Vector.concat` and `VectorSlice.concat`. *)
  val maxSize : int

  (* ---- Taking a string apart ---- *)

  (* `size s` is the number of characters of `s`. *)
  val size : string -> int

  (* `sub (s, i)` is the character of `s` at position `i`, counting from 0.

     Raises: `Subscript` if `i < 0` or `i >= size s`. *)
  val sub : string * int -> char

  (* `extract (s, i, NONE)` is the characters of `s` from position `i` on, and `extract (s, i, SOME n)` the `n` characters from `i`.

     Raises: `Subscript` if `i < 0`, if `i > size s`, or if `n` is given and
     `i + n > size s`.

     Reading: `String.extract/SOME-Subscript-not-Overflow-size`. The bound is
     tested so that it cannot overflow: an `i` and an `n` whose sum is no
     `int` raise `Subscript`, not `Overflow`.

     Example: `extract ("hello", 2, NONE) = "llo"` *)
  val extract : string * int * int option -> string

  (* `substring (s, i, n)` is the `n` characters of `s` from position `i`.

     Law: `substring (s, i, n) = extract (s, i, SOME n)`

     Raises: `Subscript` if `i < 0`, `n < 0` or `i + n > size s`.

     Example: `substring ("hello", 1, 3) = "ell"` *)
  val substring : string * int * int -> string

  (* ---- Putting strings together ---- *)

  (* `s ^ t` is the characters of `s` followed by those of `t`.

     It is infix with precedence 6.

     Raises: `Size` if the result would be longer than `maxSize`.

     Complexity: linear in `size s + size t`; both are copied. *)
  val ^ : string * string -> string

  (* `concat l` is the strings of `l` one after another.

     Raises: `Size` if the result would be longer than `maxSize`.

     Law: `concat [s, t] = s ^ t`, and `concat [] = ""` *)
  val concat : string list -> string

  (* `concatWith sep l` is the strings of `l` one after another with `sep` between them.

     There is no separator before the first or after the last, so
     `concatWith sep []` is `""` and `concatWith sep [s]` is `s`.

     Raises: `Size` if the result would be longer than `maxSize`.

     Example: `concatWith ", " ["a", "b", "c"] = "a, b, c"` *)
  val concatWith : string -> string list -> string

  (* `str c` is the string of the one character `c`. *)
  val str : char -> string

  (* `implode l` is the string of the characters of `l`, in order.

     Raises: `Size` if the result would be longer than `maxSize`. *)
  val implode : char list -> string

  (* `explode s` is the list of the characters of `s`, in order.

     Law: `implode (explode s) = s`

     Example: `explode "ab" = [#"a", #"b"]` *)
  val explode : string -> char list

  (* ---- Transforming ---- *)

  (* `map f s` is the string of the results of `f` on each character of `s`, from left to right. *)
  val map : (char -> char) -> string -> string

  (* `translate f s` applies `f` to each character of `s`, from left to right, and appends the strings it gives.

     It is `map` for a function that may give any number of characters for
     one, which is how a string is escaped or expanded.

     Raises: `Size` if the result would be longer than `maxSize`.

     Law: `translate f s = concat (List.map f (explode s))`

     Example: `translate (fn #"a" => "4" | c => str c) "banana" = "b4n4n4"` *)
  val translate : (char -> string) -> string -> string

  (* ---- Splitting ---- *)

  (* `tokens p s` is the non-empty pieces of `s` between the characters that satisfy `p`.

     A run of delimiters counts as one, and a delimiter at either end leaves
     nothing behind, so this is how a line is split into words.

     Example: `tokens Char.isSpace "  a  b " = ["a", "b"]`

     Law: `tokens p s = List.filter (fn t => size t > 0) (fields p s)` *)
  val tokens : (char -> bool) -> string -> string list

  (* `fields p s` is the pieces of `s` that the characters satisfying `p` separate.

     Every delimiter ends a field, so `n` delimiters give `n + 1` fields,
     empty ones included; this is how a line of a table is read.

     Example: `fields (fn c => c = #",") "a,,b," = ["a", "", "b", ""]` *)
  val fields : (char -> bool) -> string -> string list

  (* ---- Searching ---- *)

  (* `isPrefix p s` is `true` when `s` begins with `p`. *)
  val isPrefix : string -> string -> bool

  (* `isSubstring p s` is `true` when `p` occurs anywhere in `s`.

     The empty string occurs in every string.

     Complexity: the product of the two sizes in the worst case; the search
     is the straightforward one.

     Example: `isSubstring "" "abc" = true` *)
  val isSubstring : string -> string -> bool

  (* `isSuffix p s` is `true` when `s` ends with `p`. *)
  val isSuffix : string -> string -> bool

  (* ---- Comparing ---- *)

  (* `compare (s, t)` orders two strings by their characters' codes, lexicographically.

     A string that is a prefix of another comes before it.

     Law: `compare (s, t) = collate Char.compare (s, t)`

     Example: `compare ("abc", "abd") = LESS`

     Example: `compare ("Z", "a") = LESS` for the capitals come first in ASCII. *)
  val compare : string * string -> order

  (* `collate cmp (s, t)` compares two strings lexicographically with `cmp` for the characters.

     The answer is that of `cmp` on the first pair of characters at the same
     position that are not `EQUAL`; if there is none, the shorter string is
     `LESS`. *)
  val collate : (char * char -> order) -> string * string -> order

  (* `s < t`, `s <= t`, `s > t` and `s >= t` compare two strings as `compare` does. *)
  val < : string * string -> bool
  val <= : string * string -> bool
  val > : string * string -> bool
  val >= : string * string -> bool

  (* ---- The text of string constants ---- *)

  (* `toString s` is the text that stands for `s` inside an SML string constant.

     Every character is written as `Char.toString` writes it: the printable
     ones as themselves, with a backslash before a backslash or a double
     quote, and the others as a named escape, `\^c`, or three decimal digits.

     Law: `toString s = translate Char.toString s`

     Example: `toString "a\tb\"" = "a\\tb\\\""` *)
  val toString : string -> String.string

  (* `scan getc strm` reads the characters that `strm` begins with in the notation of SML string constants.

     It reads as many as it can and stops before the first that it cannot,
     which makes it total: the answer is `SOME (s, rest)` with the characters
     read, and `NONE` only when nothing at all could be read. A formatting
     sequence, a backslash, white space and another backslash, stands for
     nothing and is passed over, so a stream of one such sequence gives
     `SOME ""`.

     Reading: `String.scan/as-much-as-possible`. "The longest prefix" is
     taken to mean that a character that cannot be read ends the scan rather
     than failing it, and that an escape that is not one (`"a\\q"`) leaves
     what came before it.

     Reading: `String.fromString/unescaped-double-quote`. A double quote
     without a backslash converts to itself, as in SML/NJ and Poly/ML; MLton
     stops at it. `Char.scan` reads it the same way.

     Reading: `String.scan/empty-input-is-SOME-empty`. Nothing to read is no
     failure: `fromString ""` is `SOME ""`. `NONE` is for a first character
     that cannot be read, as in `fromString "\\q"`.

     Pinned by: `String.scan/empty`, `String.fromString/empty`

     Example: `fromString "" = SOME ""` *)
  val scan : (char, 'a) StringCvt.reader -> (string, 'a) StringCvt.reader

  (* `fromString s` is the characters that the text `s` begins with, read as `scan` reads them, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Reading: `String.fromString/format-first`. A formatting sequence counts
     as read although it stands for no character, so a text of nothing but
     such a sequence gives `SOME ""`, and so does one that a bad escape
     follows.

     Example: `fromString "a\\nb" = SOME "a\nb"`, where the first text has the
     two characters `\` and `n` in it. *)
  val fromString : String.string -> string option

  (* `toCString s` is the text that stands for `s` inside a C string constant.

     Every character is written as `Char.toCString` writes it, so the single
     quote and the question mark are escaped as well, and what does not print
     becomes a backslash and three octal digits.

     Example: `toCString "a\n?" = "a\\n\\?"` *)
  val toCString : string -> String.string

  (* `fromCString s` is the characters that the text `s` begins with in the notation of C, or `NONE`.

     There are no formatting sequences in C, and a double quote without a
     backslash is not a character of a constant, so it ends the scan.

     Reading: `String.fromCString/stops-at-hex-longest-sequence`. A `\x`
     escape takes "the longest sequence" of hexadecimal digits: `"\x42C"` is
     one escape of the value 1068, which is no character, and not `\x42`
     followed by `C`.

     Example: `fromCString "\\x41" = SOME "A"` *)
  val fromCString : String.string -> string option
end

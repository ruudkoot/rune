(* Integers of a fixed precision, with arithmetic that raises `Overflow`
   rather than wrapping round.

   The structures that implement this signature differ only in how many bits
   they keep: `Int` is the default one, `Int8` to `Int64` are the sized ones,
   `LargeInt` is the largest there is, and `Position` is what a file position
   is measured in. `IntInf` implements it too, through `INT_INF`, and has no
   bounds at all: there `precision`, `minInt` and `maxInt` are `NONE` and
   nothing overflows.

   Two integers of different structures are of different types, and the
   conversions between them go through `Int.int` or `LargeInt.int`
   (`toInt`, `fromInt`, `toLarge`, `fromLarge`), each of which raises
   `Overflow` when the value does not fit.

   `div` and `mod` round towards negative infinity, so the remainder has the
   sign of the divisor; `quot` and `rem` round towards zero, so the remainder
   has the sign of the dividend. The first pair is what the language's
   infix `div` and `mod` mean.

   Area: Numbers

   See also: `INT_INF`, `WORD`, `REAL`, `STRING_CVT` *)
signature INTEGER =
sig
  (* ---- The type ---- *)

  (* The type of integers of this structure.

     Implementation: `Int.int/64-bits`. `Int.int` is the top-level `int`, of
     64 bits, and so are `Int64`, `FixedInt` and `Position`; `Int8`, `Int16`
     and `Int32` keep a value of their own width, and `LargeInt` is `IntInf`,
     which has no width. Constants of each are checked against its range
     where they are written. *)
  eqtype int

  (* ---- Conversions ---- *)

  (* `toLarge i` is `i` as an integer of `LargeInt`, which loses nothing. *)
  val toLarge : int -> LargeInt.int

  (* `fromLarge i` is the integer of this structure with the value `i`.

     Raises: `Overflow` if `i` is outside the range of this structure. *)
  val fromLarge : LargeInt.int -> int

  (* `toInt i` is `i` as an integer of the default structure `Int`.

     Raises: `Overflow` if `i` is outside the range of `Int.int`. *)
  val toInt : int -> Int.int

  (* `fromInt i` is the integer of this structure with the value `i`.

     Raises: `Overflow` if `i` is outside the range of this structure. *)
  val fromInt : Int.int -> int

  (* ---- The range ---- *)

  (* `precision` is the number of bits of an integer of this structure, sign included, or `NONE` when there is no bound.

     Example: `Int.precision = SOME 64` and `IntInf.precision = NONE`. *)
  val precision : Int.int option

  (* `minInt` is the smallest integer of this structure, or `NONE` when there is none.

     Law: `minInt = SOME (~(2 ^ (p - 1)))` where `precision = SOME p` *)
  val minInt : int option

  (* `maxInt` is the largest integer of this structure, or `NONE` when there is none.

     Law: `maxInt = SOME (2 ^ (p - 1) - 1)` where `precision = SOME p`. The
     range is not symmetric: `~minInt` overflows and `abs minInt` does too.

     Example: `Int.maxInt = SOME 9223372036854775807` *)
  val maxInt : int option

  (* ---- Arithmetic ---- *)

  (* `i + j` is the sum.

     Raises: `Overflow` if the result is outside the range of this structure. *)
  val + : int * int -> int

  (* `i - j` is the difference.

     Raises: `Overflow` if the result is outside the range. *)
  val - : int * int -> int

  (* `i * j` is the product.

     Raises: `Overflow` if the result is outside the range. *)
  val * : int * int -> int

  (* `i div j` is the quotient, rounded towards negative infinity.

     Raises: `Div` if `j` is zero; `Overflow` if the result is outside the
     range, which happens for `minInt div ~1`.

     Example: `~7 div 2 = ~4`, where `~7 quot 2` is `~3`. *)
  val div : int * int -> int

  (* `i mod j` is what `div` leaves over: it has the sign of `j`.

     Raises: `Div` if `j` is zero.

     Law: `(i div j) * j + (i mod j) = i`

     Reading: `Int.mod/minInt-by-minus-one`. `mod` never raises `Overflow`,
     although `div` does at the same arguments: `minInt mod ~1` is 0.

     Example: `~7 mod 2 = 1` where `rem (~7, 2)` is `~1`. *)
  val mod : int * int -> int

  (* `quot (i, j)` is the quotient, rounded towards zero.

     Raises: `Div` if `j` is zero; `Overflow` for `quot (minInt, ~1)`.

     Example: `quot (~7, 2) = ~3`, where `~7 div 2` is `~4`. *)
  val quot : int * int -> int

  (* `rem (i, j)` is what `quot` leaves over: it has the sign of `i`.

     Raises: `Div` if `j` is zero.

     Law: `quot (i, j) * j + rem (i, j) = i`

     Reading: `Int.rem/minInt-by-minus-one`. As `mod`, it never raises
     `Overflow`: `rem (minInt, ~1)` is 0.

     Example: `rem (~7, 2) = ~1` where `~7 mod 2` is `1`. *)
  val rem : int * int -> int

  (* ---- Comparing ---- *)

  (* `compare (i, j)` orders two integers. *)
  val compare : int * int -> order

  (* `i < j`, `i <= j`, `i > j` and `i >= j` compare two integers. *)
  val < : int * int -> bool
  val <= : int * int -> bool
  val > : int * int -> bool
  val >= : int * int -> bool

  (* `~i` is the negation of `i`.

     Raises: `Overflow` for `~minInt`, which is not in the range. *)
  val ~ : int -> int

  (* `abs i` is the magnitude of `i`.

     Raises: `Overflow` for `abs minInt`. *)
  val abs : int -> int


  (* `min (i, j)` is the smaller of the two. *)
  val min : int * int -> int

  (* `max (i, j)` is the larger of the two. *)
  val max : int * int -> int

  (* `sign i` is ~1, 0 or 1, as `i` is negative, zero or positive.

     Example: `sign ~3 = ~1` *)
  val sign : int -> Int.int

  (* `sameSign (i, j)` is `true` when `i` and `j` have the same sign.

     Reading: `Int.sameSign/zero-pos`. It is "equivalent to `sign i = sign
     j`", so zero has the same sign as zero only, and not as a positive
     number.

     Law: `sameSign (i, j) = (sign i = sign j)`

     Example: `sameSign (0, 1) = false` *)
  val sameSign : int * int -> bool

  (* ---- Text ---- *)

  (* `fmt radix i` is the text of `i` in the given base, with `~` for a negative number.

     There is no prefix: a hexadecimal number is written with the digits `A`
     to `F` and nothing before them.

     Example: `fmt StringCvt.HEX 255 = "FF"` and `fmt StringCvt.BIN ~5 =
     "~101"` *)
  val fmt : StringCvt.radix -> int -> string

  (* `toString i` is the text of `i` in base 10.

     Law: `toString i = fmt StringCvt.DEC i`

     Example: `toString ~5 = "~5"` *)
  val toString : int -> string

  (* `scan radix getc strm` reads an integer in the given base from `strm`.

     It skips initial white space, takes an optional sign (`~` or `-` for a
     negative number, `+` for a positive one) and then the digits. In
     `StringCvt.HEX` an optional `0x` or `0X` may stand before them. The
     answer is `SOME (i, rest)`, or `NONE` when no digit is there, and then
     nothing has been consumed.

     Raises: `Overflow` if the digits name a number outside the range of this
     structure.

     Reading: `Int.scan/HEX-bare-prefix-0x`. A `0x` that no digit follows is
     not a prefix, but its `0` is a digit: `"0xg"` scans as 0 and leaves
     `"xg"` in the stream.

     Example: `StringCvt.scanString (scan StringCvt.HEX) "0x1F" = SOME 31` *)
  val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (int, 'a) StringCvt.reader

  (* `fromString s` is the integer that the text `s` begins with in base 10, or `NONE`.

     Raises: `Overflow` if the digits name a number outside the range.

     Law: `fromString s = StringCvt.scanString (scan StringCvt.DEC) s`

     Example: `fromString " +12x" = SOME 12`

     Example: `fromString "0x1F" = SOME 0` for it reads decimal digits only. *)
  val fromString : string -> int option
end

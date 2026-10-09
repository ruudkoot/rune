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

     Implementation: `Int.int/63-bits`. `Int.int` is the top-level `int`,
     whose width is the VM's: 63 bits on this one, a word of the machine less
     the bit that tells a number from a pointer, so that `Int.precision` is
     `SOME 63`. `Position` is `Int`. `Int64` and `FixedInt` are of 64 bits, a
     type of their own: a number of theirs is kept in a word where it fits 63
     bits and in a small object where it needs the 64th, so that code written
     for 64 bits has them on every machine; `Int8`, `Int16` and `Int32` keep
     a value of their own width, and `LargeInt` is `IntInf`, which has no
     width. Constants of each are checked against its
     range where they are written. *)
  eqtype int

  (* ---- Conversions ---- *)

  (* `toLarge i` is `i` as an integer of `LargeInt`, which loses nothing.

     Law: `fromLarge (toLarge i) = i`

     Example: `toLarge 5 = 5` *)
  val toLarge : int -> LargeInt.int

  (* `fromLarge i` is the integer of this structure with the value `i`.

     Raises: `Overflow` if `i` is outside the range of this structure.

     Law: `toLarge (fromLarge i) = i` when `(case minInt of NONE => true | SOME
     m => LargeInt.<= (toLarge m, i)) andalso (case maxInt of NONE => true |
     SOME m => LargeInt.<= (i, toLarge m))`

     Example: `fromLarge (IntInf.pow (2, 10)) = 1024` *)
  val fromLarge : LargeInt.int -> int

  (* `toInt i` is `i` as an integer of the default structure `Int`.

     Raises: `Overflow` if `i` is outside the range of `Int.int`.

     Law: `fromInt (toInt i) = i` when `(case Int.minInt of NONE => true | SOME
     m => LargeInt.<= (Int.toLarge m, toLarge i)) andalso (case Int.maxInt of
     NONE => true | SOME m => LargeInt.<= (toLarge i, Int.toLarge m))`

     Example: `toInt 7 = 7` *)
  val toInt : int -> Int.int

  (* `fromInt i` is the integer of this structure with the value `i`.

     Raises: `Overflow` if `i` is outside the range of this structure.

     Example: `((Int8.fromInt 200; "fits") handle Overflow => "Overflow") =
     "Overflow"` *)
  val fromInt : Int.int -> int

  (* ---- The range ---- *)

  (* `precision` is the number of bits of an integer of this structure, sign included, or `NONE` when there is no bound.

     Example: `Int.precision = SOME 63`

     Example: `Int64.precision = SOME 64`

     Example: `IntInf.precision = NONE` *)
  val precision : Int.int option

  (* `minInt` is the smallest integer of this structure, or `NONE` when there is none.

     Law: `case precision of SOME p => minInt = SOME (fromLarge (IntInf.~
     (IntInf.pow (2, Int.- (p, 1))))) | NONE => true`

     Example: `Int.minInt = SOME ~4611686018427387904`

     Example: `Int64.minInt = SOME ~9223372036854775808` *)
  val minInt : int option

  (* `maxInt` is the largest integer of this structure, or `NONE` when there is none.

     The range is not symmetric: `~minInt` overflows and `abs minInt` does
     too.

     Law: `case precision of SOME p => maxInt = SOME (fromLarge (IntInf.-
     (IntInf.pow (2, Int.- (p, 1)), 1))) | NONE => true`

     Example: `Int.maxInt = SOME 4611686018427387903`

     Example: `Int64.maxInt = SOME 9223372036854775807` *)
  val maxInt : int option

  (* ---- Arithmetic ---- *)

  (* `i + j` is the sum.

     Raises: `Overflow` if the result is outside the range of this structure.

     Example: `((valOf maxInt + 1; "fits") handle Overflow => "Overflow") =
     "Overflow"` *)
  val + : int * int -> int

  (* `i - j` is the difference.

     Raises: `Overflow` if the result is outside the range.

     Law: `i - j = i + ~j` when `minInt <> SOME j`

     Example: `3 - 5 = ~2` *)
  val - : int * int -> int

  (* `i * j` is the product.

     Raises: `Overflow` if the result is outside the range.

     Example: `~3 * 4 = ~12` *)
  val * : int * int -> int

  (* `i div j` is the quotient, rounded towards negative infinity.

     Raises: `Div` if `j` is zero; `Overflow` if the result is outside the
     range, which happens for `minInt div ~1`.

     It rounds down, where `quot` rounds towards zero: `quot (~7, 2)` is `~3`.

     Example: `~7 div 2 = ~4` *)
  val div : int * int -> int

  (* `i mod j` is what `div` leaves over: it has the sign of `j`.

     Raises: `Div` if `j` is zero.

     Law: `LargeInt.+ (LargeInt.* (toLarge (i div j), toLarge j), toLarge (i
     mod j)) = toLarge i` for `j <> 0 andalso (j <> ~1 orelse minInt <> SOME
     i)`. It is computed in `LargeInt`: in `int` the product can overflow where
     neither `div` nor `mod` does.

     Reading: `Int.mod/minInt-by-minus-one`. `mod` never raises `Overflow`,
     although `div` does at the same arguments: `minInt mod ~1` is 0.

     Its sign is the divisor's, where that of `rem` is the dividend's:
     `rem (~7, 2)` is `~1`.

     Example: `~7 mod 2 = 1`

     Counterexample: `(1 div 0) * 0 + (1 mod 0) = 1`, for there is no dividing
     by zero; `(valOf minInt div ~1) * ~1 + (valOf minInt mod ~1) = valOf
     minInt`, for that quotient is past the largest int; and `(valOf maxInt div
     ~2) * ~2 + (valOf maxInt mod ~2) = valOf maxInt`, for the product is past
     the largest int, though the quotient and the remainder are not. *)
  val mod : int * int -> int

  (* `quot (i, j)` is the quotient, rounded towards zero.

     Raises: `Div` if `j` is zero; `Overflow` for `quot (minInt, ~1)`.

     It rounds towards zero, where `div` rounds down: `~7 div 2` is `~4`.

     Example: `quot (~7, 2) = ~3` *)
  val quot : int * int -> int

  (* `rem (i, j)` is what `quot` leaves over: it has the sign of `i`.

     Raises: `Div` if `j` is zero.

     Law: `quot (i, j) * j + rem (i, j) = i` for `j <> 0 andalso (j <> ~1
     orelse minInt <> SOME i)`

     Reading: `Int.rem/minInt-by-minus-one`. As `mod`, it never raises
     `Overflow`: `rem (minInt, ~1)` is 0.

     Its sign is the dividend's, where that of `mod` is the divisor's:
     `~7 mod 2` is `1`.

     Example: `rem (~7, 2) = ~1`

     Counterexample: `quot (1, 0) * 0 + rem (1, 0) = 1`, for there is no
     dividing by zero, and `quot (valOf minInt, ~1) * ~1 + rem (valOf minInt,
     ~1) = valOf minInt`, for that quotient is past the largest int. *)
  val rem : int * int -> int

  (* ---- Comparing ---- *)

  (* `compare (i, j)` orders two integers.

     Law: `(compare (i, j) = EQUAL) = (i = j)`

     Example: `compare (~1, 1) = LESS` *)
  val compare : int * int -> order

  (* `i < j`, `i <= j`, `i > j` and `i >= j` compare two integers.

     Law: `(i < j) = (compare (i, j) = LESS)`, and `(i <= j) = (compare (i, j)
     <> GREATER)`, and `(i > j) = (compare (i, j) = GREATER)`, and `(i >= j) =
     (compare (i, j) <> LESS)`

     Example: `~3 < 2 = true` *)
  val < : int * int -> bool
  val <= : int * int -> bool
  val > : int * int -> bool
  val >= : int * int -> bool

  (* `~i` is the negation of `i`.

     Raises: `Overflow` for `~minInt`, which is not in the range.

     Law: `~ (~ i) = i` when `minInt <> SOME i`

     Example: `~ (~5) = 5` *)
  val ~ : int -> int

  (* `abs i` is the magnitude of `i`.

     Raises: `Overflow` for `abs minInt`.

     Law: `abs i = (if i < 0 then ~i else i)`

     Example: `abs ~5 = 5` *)
  val abs : int -> int

  (* `min (i, j)` is the smaller of the two.

     Law: `min (i, j) = (if i < j then i else j)`

     Example: `min (3, ~2) = ~2` *)
  val min : int * int -> int

  (* `max (i, j)` is the larger of the two.

     Law: `max (i, j) = (if i < j then j else i)`

     Example: `max (3, ~2) = 3` *)
  val max : int * int -> int

  (* `sign i` is ~1, 0 or 1, as `i` is negative, zero or positive.

     Law: `fromInt (sign i) * abs i = i` when `minInt <> SOME i`

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

     Example: `fmt StringCvt.HEX 255 = "FF"`

     Example: `fmt StringCvt.BIN ~5 = "~101"` *)
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

     It reads decimal digits only, so a prefix of base 16 stops it after the
     `0`:

     Example: `fromString "0x1F" = SOME 0` *)
  val fromString : string -> int option
end

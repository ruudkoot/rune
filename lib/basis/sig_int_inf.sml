(* Integers of arbitrary precision: everything `INTEGER` has, and the
   operations that make sense only, or mostly, without a bound.

   `IntInf.int` has no smallest and no largest value: `precision`, `minInt`
   and `maxInt` are `NONE`, and no operation raises `Overflow` except the
   conversions to a bounded type. The bit operations treat an integer as an
   infinite string of bits in two's complement, so that a negative number has
   infinitely many leading ones and `notb i` is `~(i + 1)`.

   Area: Numbers

   Status: optional

   See also: `INTEGER`, `WORD`

   Implementation: `IntInf.int/limbs`. A sign and a list of digits in base
   2^30, written in SML on top of the 64-bit `int`; equal numbers are equal
   values, so `=` compares them. `LargeInt` is `IntInf`.

   Implementation: `INT_INF/constants`. An integer constant may have the type
   `IntInf.int`, and then be of any size, and the overloaded operators work
   at it. The specification promises neither, so the suite builds its numbers
   with `fromInt`, `fromString` and arithmetic. *)
signature INT_INF =
sig
  include INTEGER

  (* ---- Division ---- *)

  (* `divMod (i, j)` is the pair `(i div j, i mod j)`, computed in one
     division.

     The quotient is rounded towards negative infinity and the remainder has
     the sign of `j`.

     Raises: `Div` if `j` is zero.

     Example: `divMod (~7, 2) = (~4, 1)` *)
  val divMod : int * int -> int * int

  (* `quotRem (i, j)` is the pair `(quot (i, j), rem (i, j))`, computed in one
     division.

     The quotient is rounded towards zero and the remainder has the sign of
     `i`.

     Raises: `Div` if `j` is zero.

     Example: `quotRem (~7, 2) = (~3, ~1)` *)
  val quotRem : int * int -> int * int

  (* ---- Powers and logarithms ---- *)

  (* `pow (i, j)` is `i` to the power `j`.

     For a negative `j` the result is what is left of `1 / i^~j` as an integer:
     1 or ~1 when `i` is 1 or ~1, and 0 for every other `i` but 0.

     Raises: `Div` if `i` is zero and `j` is negative.

     Example: `pow (2, 100) = 1267650600228229401496703205376` *)
  val pow : int * Int.int -> int

  (* `log2 i` is the largest `k` for which `2^k <= i`: the position of the
     highest bit of `i`.

     Raises: `Domain` if `i <= 0`.

     Example: `log2 (pow (2, 100)) = 100` *)
  val log2 : int -> Int.int

  (* ---- Bits ---- *)

  (* `orb (i, j)` is the bitwise "or" of `i` and `j`. *)
  val orb : int * int -> int

  (* `xorb (i, j)` is the bitwise exclusive "or" of `i` and `j`. *)
  val xorb : int * int -> int

  (* `andb (i, j)` is the bitwise "and" of `i` and `j`.

     Example: `andb (~1, 255) = 255` for a negative number has ones without end
     to the left. *)
  val andb : int * int -> int

  (* `notb i` is `i` with every bit inverted.

     Law: `notb i = ~(i + 1)`

     Example: `notb 0 = ~1` *)
  val notb : int -> int

  (* `<< (i, n)` is `i` shifted left by `n` bits: `i * 2^n`.

     Example: `<< (1, 0w100) = pow (2, 100)` *)
  val << : int * Word.word -> int

  (* `~>> (i, n)` is `i` shifted right by `n` bits with its sign kept: `i div
     2^n`, rounded towards negative infinity.

     Example: `~>> (~5, 0w1) = ~3` *)
  val ~>> : int * Word.word -> int
end

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

   Implementation: `IntInf.int/limbs`. A type of the VM's: a number that
   fits 63 bits is an immediate, the same word as an `int` of it, and a
   larger one a sign and immutable little-endian magnitude bytes.
   Normalization gives equal numbers equal values, so `=` compares them.
   `LargeInt` is `IntInf`. Addition, subtraction, multiplication, the four
   divisions, negation, the comparisons and the conversions from and to
   `int` are primitives of the VM, which do two immediates in line, as an
   `int`'s are done, and the rest in the runtime: with GMP's multiplication
   and division where the register VM selects GMP and an operand is large,
   and otherwise with its own 32-bit digits, in memory of its own freed
   before the primitive returns. The bit operations, the shifts, `pow` and
   the conversions to text and from it are SML over a number's sign and
   magnitude, with indexed 30-bit scratch digits (15-bit on narrow hosts)
   that storage primitives pack and unpack, or GMP's where it is selected.
   Every path enforces a finite operational magnitude budget (134217728 bits
   by default), with a runtime-limit failure rather than `Overflow` when it
   is exceeded. The budget is configurable and does not change
   `precision = NONE`. Normalization checks the machine boundary without
   raising an exception. The SML paths reuse private scratch digits for bit
   operations and right shifts, returning small results without packing
   them first. Positive OR/XOR with a small operand visits only low bytes.
   Public values remain immutable.

   Decimal formatting uses GMP's conversion when that backend is selected.
   The independent SML formatter overwrites one private quotient workspace
   while extracting decimal chunks, avoiding quadratic temporary allocation.
   SML supplies the sign in both cases; zero prints as `0` and a negative
   value starts with `~`. Formatting a large value obeys the magnitude budget.

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

     Law: `divMod (i, j) = (i div j, i mod j)`

     Example: `divMod (~7, 2) = (~4, 1)` *)
  val divMod : int * int -> int * int

  (* `quotRem (i, j)` is the pair `(quot (i, j), rem (i, j))`, computed in one
     division.

     The quotient is rounded towards zero and the remainder has the sign of
     `i`.

     Raises: `Div` if `j` is zero.

     Law: `quotRem (i, j) = (quot (i, j), rem (i, j))`

     Example: `quotRem (~7, 2) = (~3, ~1)` *)
  val quotRem : int * int -> int * int

  (* ---- Powers and logarithms ---- *)

  (* `pow (i, j)` is `i` to the power `j`.

     For a negative `j` the result is what is left of `1 / i^~j` as an integer:
     1 when `i` is 1; for `i` of ~1, ~1 when `j` is odd and 1 when it is even;
     and 0 for every other `i` but 0.

     Raises: `Div` if `i` is zero and `j` is negative.

     Law: `pow (i, Int.+ (j, k)) = pow (i, j) * pow (i, k)` for `Int.>= (j, 0)
     andalso Int.>= (k, 0)`, and it is run for `j` from `Arb.intRange (0, 15)`
     and `k` from `Arb.intRange (0, 15)`, as a larger power of a large number
     takes long

     Example: `pow (2, 100) = 1267650600228229401496703205376`

     Example: `pow (~1, ~3) = ~1` *)
  val pow : int * Int.int -> int

  (* `log2 i` is the largest `k` for which `2^k <= i`: the position of the
     highest bit of `i`.

     Raises: `Domain` if `i <= 0`.

     Law: `pow (2, log2 i) <= i andalso i < pow (2, Int.+ (log2 i, 1))` for `i
     > 0`

     Example: `log2 (pow (2, 100)) = 100` *)
  val log2 : int -> Int.int

  (* ---- Bits ---- *)

  (* `orb (i, j)` is the bitwise "or" of `i` and `j`.

     Example: `orb (12, 3) = 15` *)
  val orb : int * int -> int

  (* `xorb (i, j)` is the bitwise exclusive "or" of `i` and `j`.

     Law: `xorb (i, i) = 0`

     Example: `xorb (12, 10) = 6` *)
  val xorb : int * int -> int

  (* `andb (i, j)` is the bitwise "and" of `i` and `j`.

     A negative number has ones without end to the left:

     Example: `andb (~1, 255) = 255` *)
  val andb : int * int -> int

  (* `notb i` is `i` with every bit inverted.

     Law: `notb i = ~(i + 1)`

     Example: `notb 0 = ~1` *)
  val notb : int -> int

  (* `<< (i, n)` is `i` shifted left by `n` bits: `i * 2^n`.

     Law: `<< (i, n) = i * pow (2, Word.toInt n)`, run for `n` from
     `Arb.wordRange (0w0, 0w4095)`

     Example: `<< (1, 0w100) = pow (2, 100)` *)
  val << : int * Word.word -> int

  (* `~>> (i, n)` is `i` shifted right by `n` bits with its sign kept: `i div
     2^n`, rounded towards negative infinity.

     Law: `~>> (i, n) = i div pow (2, Word.toInt n)`, run for `n` from
     `Arb.wordRange (0w0, 0w4095)`, as `Word.toInt n` overflows for a larger
     shift

     Example: `~>> (~5, 0w1) = ~3` *)
  val ~>> : int * Word.word -> int
end

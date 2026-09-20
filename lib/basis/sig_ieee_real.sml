(* The parts of IEEE 754 arithmetic that are not about one real number: the
   rounding mode, the classes a number can belong to, and an exact decimal
   form to convert through.

   `REAL` has everything that computes with reals; what is here is the state
   of the floating-point unit, and the type `decimal_approx`, which is a
   number written out in decimal digits and so can be converted to and from
   text without losing anything.

   Area: Numbers

   Status: optional

   See also: `REAL`, `MATH`, `STRING_CVT` *)
signature IEEE_REAL =
sig
  (* Raised by `Real.compare` when one of its arguments is a NaN, which no
     order relates to anything. It is the top-level `Unordered`. *)
  exception Unordered

  (* How two reals compare, with a fourth answer for the pairs that no order relates.

     `Real.compareReal` gives it; `Real.compare` raises `Unordered` instead. *)
  datatype real_order = LESS | EQUAL | GREATER | UNORDERED

  (* What kind of number a real is.

     Every real is of exactly one class, which `Real.class` gives. *)
  datatype float_class
    = NAN         (* not a number: the result of 0.0/0.0 and its like *)
    | INF         (* an infinity, of either sign *)
    | ZERO        (* a zero, of either sign *)
    | NORMAL      (* an ordinary number *)
    | SUBNORMAL   (* a number too small to be normal, with fewer digits of precision *)

  (* Where a result that is not exact is rounded to.

     `TO_NEAREST` is what a program gets unless it asks for another, and
     under it a result exactly between two reals goes to the one whose last
     digit is even. *)
  datatype rounding_mode
    = TO_NEAREST   (* to the nearest, ties to even *)
    | TO_NEGINF    (* down *)
    | TO_POSINF    (* up *)
    | TO_ZERO      (* towards zero: the result is truncated *)

  (* `setRoundingMode m` makes `m` the rounding mode of what follows.

     It changes the state of the floating-point unit, so it holds for every
     operation until it is set again.

     Implementation: `IEEEReal.setRoundingMode/fesetround`. The mode of the C
     library, set with `fesetround`. *)
  val setRoundingMode : rounding_mode -> unit

  (* `getRoundingMode ()` is the rounding mode in force. *)
  val getRoundingMode : unit -> rounding_mode

  (* A real written out in decimal: the sign, the digits and the exponent.

     The number is `0.d1d2...dn` times `10^exp`, negated when `sign` is
     `true`, so the point stands before the first digit. For a `class` of
     `ZERO`, `INF` or `NAN` the digits and the exponent say nothing. *)
  type decimal_approx = {class : float_class,   (* which kind of number it is *)
                         sign : bool,           (* true for a negative number, a negative zero included *)
                         digits : int list,     (* the digits after the point, each from 0 to 9 *)
                         exp : int}             (* the power of ten to multiply by *)

  (* `toString d` is the text of `d`: `[~]0.d1d2...dnE[~]exp`.

     A zero is written `0.0`, an infinity `inf` and a NaN `nan`, each with a
     `~` before it when the sign is set, and the exponent is left out when it
     is zero.

     Example: `toString {class = NORMAL, sign = false, digits = [1, 5], exp =
     1} = "0.15E1"` *)
  val toString : decimal_approx -> string

  (* `scan getc strm` reads a decimal number, an infinity or a NaN from `strm`.

     It skips initial white space and then takes an optional sign (`~`, `-`
     or `+`) and either digits with an optional point and an optional
     exponent (`1.5`, `.5`, `15E~1`), or one of the words `inf`, `infinity`
     and `nan` in any mixture of upper and lower case. Every digit that is
     there is kept, however many.

     Reading: `IEEEReal.scan/huge-exponent`. An exponent whose digits name a
     number too large for an `int` is taken as the largest `int` rather than
     raising `Overflow`: the number it describes is beyond every real
     anyway. *)
  val scan : (char, 'a) StringCvt.reader -> (decimal_approx, 'a) StringCvt.reader

  (* `fromString s` is the decimal number that the text `s` begins with, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s` *)
  val fromString : string -> decimal_approx option
end

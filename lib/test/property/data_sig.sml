(* The arbitraries of `Date.date`, of its months, weekdays and record of
   fields, by the generator principle P12 (docs/plans/quickcheck.md).

   A date is made by `Date.date` from fields in range: a year from 1900 to
   2200 (the years the specification asks for), any month, a day from 1 to
   31, an hour, a minute and a second in range, and the local zone or an
   offset within a day. The record of fields is drawn around those ranges,
   widened on each side by their own width, so that fields out of range and
   on its edges are drawn as often as fields in it; its year is any `int`.

   Area: Property testing *)
signature DATE_ARB =
sig
  (* The type of dates. *)
  type t = Date.date

  (* The arbitrary of dates. Two dates are equal when `Date.compare` says
     so and their offsets are the same. *)
  val arb : Date.date Arb.arb

  (* The arbitrary of months, `Date.Jan` the simplest. *)
  val month : Date.month Arb.arb

  (* The arbitrary of weekdays, `Date.Mon` the simplest. *)
  val weekday : Date.weekday Arb.arb

  (* The arbitrary of the records of fields that `Date.date` takes. *)
  val fields : {year : int, month : Date.month, day : int, hour : int, minute : int, second : int,
                offset : Time.time option} Arb.arb
end

(* The arbitraries of `IEEEReal`'s types, by the generator principle P12.

   Area: Property testing *)
signature IEEE_REAL_ARB =
sig
  (* The arbitrary of rounding modes, `IEEEReal.TO_NEAREST` the simplest. *)
  val roundingMode : IEEEReal.rounding_mode Arb.arb

  (* The arbitrary of classes of reals, `IEEEReal.NAN` the simplest. *)
  val floatClass : IEEEReal.float_class Arb.arb

  (* The arbitrary of decimal approximations.

     The class is any, the sign either, the digits a list of integers from
     ~10 to 19 (the digits and as many on either side), and the exponent any
     `int`. *)
  val decimalApprox : IEEEReal.decimal_approx Arb.arb
end

(* The arbitraries of the small datatypes and readers of the Basis Library.

   Area: Property testing *)
signature BASIS_DATA_ARB =
sig
  (* The arbitrary of buffer modes, `IO.NO_BUF` the simplest. *)
  val bufferMode : IO.buffer_mode Arb.arb

  (* The arbitrary of radixes, `StringCvt.BIN` the simplest. *)
  val radix : StringCvt.radix Arb.arb

  (* The arbitrary of the orders in which `Array2` traverses an array,
     `Array2.RowMajor` the simplest. *)
  val traversal : Array2.traversal Arb.arb

  (* The arbitrary of readers of characters over a drawn string, whose stream is a position in it.

     The string is drawn as `Arb.string` draws one. From `i`, the reader gives
     the character at `i` and the position `i + 1`, and `NONE` at the end or
     outside the string. *)
  val reader : (char, int) StringCvt.reader Arb.arb
end

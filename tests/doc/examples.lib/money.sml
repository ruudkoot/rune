(* Amounts of money.

   Area: Tests

   Example: `add (zero, zero) = zero` *)
signature MONEY =
sig
  (* An amount. *)
  eqtype t

  (* Nothing. *)
  val zero : t

  (* `add (a, b)` is the sum of `a` and `b`.

     Example: `add (zero, zero) = zero` holds, `add zero` is no equation and
     is only shown, and another structure is named in full: `Euros.add
     (Euros.zero, Euros.zero) = Euros.zero`. *)
  val add : t * t -> t

  (* `show a` is `a` for a reader.

     Example: `show zero = "0"`

     Example: `show zero = 0` is ill-typed, `show nothing = "0"` names what is
     not there, and `show = show` compares what has no equality. *)
  val show : t -> string

  (* Rounding. *)
  structure Round :
  sig
    (* `down a` is `a` without its fraction.

       Example: `down zero = zero` *)
    val down : t -> t
  end
end

(* Implements: MONEY

   Status: optional *)
structure Euros =
struct
  type t = int
  val zero = 0
  fun add (a, b) = a + b : int
  fun show (_ : t) = "0"
  structure Round = struct fun down (a : t) = a end
end

(* Implements: MONEY *)
structure Cents =
struct
  type t = int
  val zero = 0
  fun add (a, b) = a + b : int
  fun show (_ : t) = "0"
  structure Round = struct fun down (a : t) = a end
end

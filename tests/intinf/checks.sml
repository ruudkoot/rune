(* Independent decimal fixtures and algebraic checks. The small interface
   admits the saved oracle without making its type equal to LargeInt.int. *)
signature INTINF_CHECK =
sig
  eqtype int
  val fromString : string -> int option
  val fromInt : Int.int -> int
  val toString : int -> string
  val + : int * int -> int
  val - : int * int -> int
  val * : int * int -> int
  val divMod : int * int -> int * int
  val quotRem : int * int -> int * int
  val andb : int * int -> int
  val orb : int * int -> int
  val xorb : int * int -> int
  val notb : int -> int
  val << : int * Word.word -> int
  val ~>> : int * Word.word -> int
  val pow : int * Int.int -> int
  val log2 : int -> Int.int
end

functor IntInfChecksFn (structure I : INTINF_CHECK val name : string) =
struct
  val checks = ref 0
  fun number s = valOf (I.fromString s)
  fun assert (label, yes) =
    if yes then checks := !checks + 1
    else raise Fail (name ^ ": " ^ label)
  fun check (sa, sb, expected) =
    let
      val a = number sa and b = number sb
      val (dq, dr) = I.divMod (a, b)
      val (tq, tr) = I.quotRem (a, b)
      val actual = List.map I.toString
        [I.+ (a,b), I.- (a,b), I.* (a,b), dq, dr, tq, tr,
         I.andb (a,b), I.orb (a,b), I.xorb (a,b), I.notb a,
         I.<< (a, 0w31), I.~>> (a, 0w31)]
      val () = assert (sa ^ " / " ^ sb, actual = expected)
      val () = assert ("floor identity", I.+ (I.* (dq,b),dr) = a)
      val () = assert ("truncation identity", I.+ (I.* (tq,b),tr) = a)
      val () = assert ("canonical zero", I.- (a,a) = I.fromInt 0)
      val () = assert ("round trip", number (I.toString a) = a)
    in () end
  val () = List.app check IntInfVectors.cases
  val () = assert ("zero power", I.pow (I.fromInt 0, 0) = I.fromInt 1)
  val () = assert ("negative exponent", I.pow (I.fromInt (~1), ~3) = I.fromInt (~1))
  val () = assert ("Div", (I.divMod (I.fromInt 1, I.fromInt 0); false) handle Div => true)
  val () = assert ("Domain", (I.log2 (I.fromInt 0); false) handle Domain => true)
  val () = print (name ^ ": " ^ Int.toString (!checks) ^ " checks\n")
end

structure CheckCurrent = IntInfChecksFn (structure I = IntInf val name = "current")
structure CheckOracle = IntInfChecksFn (structure I = IntInfOracle val name = "oracle")

(* requires: Int LargeInt *)
(* uses: fn/numstr.sml fn/integer_fn.sml *)
(* The Int structure (signature INTEGER). Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html. The checks that hold for
   every INTEGER structure are in fn/integer_fn.sml, those of fmt and scan in
   int_scan.sml; here are the ones of the default integer type. *)
structure TestInt =
struct
  structure Generic = TestIntegerFn (structure I = Int val name = "Int")

  val eqI = T.eq T.int
  val eqB = T.eq T.bool

  (* "structure Int :> INTEGER where type int = int" *)
  val () = eqI ("Int.int/is-toplevel-int", 5, fn () => (Int.+ (2 : int, 3 : int) : Int.int))
  val () = eqI ("Int.int/toplevel-is-Int.int", 5, fn () => (2 : Int.int) + (3 : Int.int))
  (* for Int, the default integer type is the type itself *)
  val () = eqI ("Int.toInt/identity", 42, fn () => Int.toInt 42)
  val () = eqI ("Int.fromInt/identity", ~42, fn () => Int.fromInt ~42)
  val () = T.check ("Int.toInt/identity-on-bounds",
                    fn () => Option.map Int.toInt Int.maxInt = Int.maxInt
                             andalso Option.map Int.toInt Int.minInt = Int.minInt)
  val () = T.check ("Int.fromInt/identity-on-bounds",
                    fn () => Option.map Int.fromInt Int.maxInt = Int.maxInt
                             andalso Option.map Int.fromInt Int.minInt = Int.minInt)

  (* the top-level operators, which default to int, are those of Int *)
  val () = T.seed 5
  val () = T.repeat (25, fn k =>
    let
      val s = "-" ^ Int.toString k
      val a = T.range (~30000, 30000)
      val b = T.range (~30000, 30000)
      val d = if b = 0 then 7 else b
    in
      eqI ("Int.+/toplevel" ^ s, Int.+ (a, b), fn () => a + b);
      eqI ("Int.-/toplevel" ^ s, Int.- (a, b), fn () => a - b);
      eqI ("Int.*/toplevel" ^ s, Int.* (a, b), fn () => a * b);
      eqI ("Int.div/toplevel" ^ s, Int.div (a, d), fn () => a div d);
      eqI ("Int.mod/toplevel" ^ s, Int.mod (a, d), fn () => a mod d);
      eqI ("Int.~/toplevel" ^ s, Int.~ a, fn () => ~ a);
      eqI ("Int.abs/toplevel" ^ s, Int.abs a, fn () => abs a);
      eqB ("Int.</toplevel" ^ s, Int.< (a, b), fn () => a < b);
      eqB ("Int.<=/toplevel" ^ s, Int.<= (a, b), fn () => a <= b);
      eqB ("Int.>/toplevel" ^ s, Int.> (a, b), fn () => a > b);
      eqB ("Int.>=/toplevel" ^ s, Int.>= (a, b), fn () => a >= b)
    end)
  val () = eqI ("Int.div/toplevel-floor", ~4, fn () => ~7 div 2)
  val () = eqI ("Int.mod/toplevel-sign-of-divisor", ~1, fn () => 7 mod ~2)
  val () = T.raises ("Int.div/toplevel-Div", T.isDiv, fn () => 1 div 0)
  val () = T.raises ("Int.mod/toplevel-Div", T.isDiv, fn () => 1 mod 0)
  val () =
    case (Int.maxInt, Int.minInt) of
      (SOME hi, SOME lo) =>
        (T.raises ("Int.+/toplevel-Overflow", T.isOverflow, fn () => hi + 1);
         T.raises ("Int.-/toplevel-Overflow", T.isOverflow, fn () => lo - 1);
         T.raises ("Int.*/toplevel-Overflow", T.isOverflow, fn () => hi * 2);
         T.raises ("Int.~/toplevel-Overflow", T.isOverflow, fn () => ~ lo);
         T.raises ("Int.abs/toplevel-Overflow", T.isOverflow, fn () => abs lo);
         T.raises ("Int.div/toplevel-Overflow", T.isOverflow, fn () => lo div ~1))
    | _ => ()
end

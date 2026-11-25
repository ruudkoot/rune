(* Constant folding for the Core simplifier (the haskell98 roadmap's M23,
   with Augustsson 1993, §4.3): a primitive given literals, where its value
   is the one the primitive gives at run time and it cannot raise, and a
   literal of `fromInteger` and `fromRational` at the Prelude's own instance
   of `Double` or `Float`, as desugaring writes one where it knows the
   instance (HsDsEnv.integerLit, rationalLit).

   A floating literal is made as its exact decimal text, which the
   interpreter and Core to Mid read correctly rounded as they read a
   written one; one that has no exact decimal text, or is past what the
   type holds exactly, is left to the program. *)
structure CoreSimplifyFold =
struct
  open Core

  val zero = IntInf.fromInt 0
  val one = IntInf.fromInt 1
  val two = IntInf.fromInt 2
  val five = IntInf.fromInt 5
  val ten = IntInf.fromInt 10

  (* the range of Int, the target's (63 bits), which rhc runs on too *)
  fun inIntRange (i : IntInf.int) : bool = (ignore (Int.fromLarge i); true) handle Overflow => false

  fun bool b = Con (if b then "True" else "False", [], [])

  (* the decimal text of i, with - for a minus *)
  fun decimal (i : IntInf.int) : string =
    if IntInf.< (i, zero) then "-" ^ IntInf.toString (IntInf.~ i) else IntInf.toString i

  (* the exact decimal text of n / d, where d has no prime factor but 2
     and 5: digits, a point, at least one digit after it *)
  fun exactText (n : IntInf.int, d : IntInf.int) : string option =
    let
      fun strip (d, p, k) = if IntInf.rem (d, p) = zero then strip (IntInf.quot (d, p), p, k + 1) else (d, k)
      val (d2, a) = strip (d, two, 0)
      val (rest, b) = strip (d2, five, 0)
    in
      if rest <> one orelse IntInf.<= (d, zero) then NONE
      else
        let
          val k = Int.max (a, b)
          (* n / d = n * 2^(k-a) * 5^(k-b) / 10^k *)
          val digits = IntInf.* (n, IntInf.* (IntInf.pow (two, k - a), IntInf.pow (five, k - b)))
          val neg = IntInf.< (digits, zero)
          val s = IntInf.toString (IntInf.abs digits)
          val s = if String.size s <= k then CharVector.tabulate (k + 1 - String.size s, fn _ => #"0") ^ s else s
          val whole = String.substring (s, 0, String.size s - k)
          val frac = if k = 0 then "0" else String.extract (s, String.size s - k, NONE)
        in SOME ((if neg then "-" else "") ^ whole ^ "." ^ frac) end
    end

  (* the bits of |i| *)
  fun bits (i : IntInf.int) : int =
    let fun go (i, n) = if i = zero then n else go (IntInf.quot (i, two), n + 1)
    in go (IntInf.abs i, 0) end

  (* the text of m * 2^e, exactly, where a value of `mantissa` bits holds
     it as a normal number *)
  fun encodeText (mantissa : int, m : IntInf.int, e : int) : string option =
    if bits m > mantissa orelse e < ~900 orelse e + bits m > 120 andalso mantissa = 24 orelse e + bits m > 1000 then NONE
    else if mantissa = 24 andalso m <> zero andalso e + bits m < ~120 then NONE
    else if e >= 0 then SOME (decimal (IntInf.* (m, IntInf.pow (two, e))) ^ ".0")
    else exactText (m, IntInf.pow (two, ~e))

  fun lit l = Atom (Lit l)

  (* `prim (p, atoms)` is the value of the primitive p given atoms, where
     it is a literal it is known to give *)
  fun prim (p : string, atoms : atom list) : exp option =
    let
      fun ints f = case atoms of [Lit (LInt a), Lit (LInt b)] => f (a, b) | _ => NONE
      fun integers f = case atoms of [Lit (LInteger a), Lit (LInteger b)] => f (a, b) | _ => NONE
      fun chars f = case atoms of [Lit (LChar a), Lit (LChar b)] => f (a, b) | _ => NONE
      fun int i = if inIntRange i then SOME (lit (LInt i)) else NONE
      fun integer i = SOME (lit (LInteger i))
      fun ccompare (c : int * int -> bool) (a, b) = SOME (bool (c (a, b)))
      fun after prefix = if String.isPrefix prefix p then SOME (String.extract (p, size prefix, NONE)) else NONE
    in
      case (p, atoms) of
        ("int_neg", [Lit (LInt a)]) => int (IntInf.~ a)
      | ("integer_neg", [Lit (LInteger a)]) => integer (IntInf.~ a)
      | ("integer_from_int", [Lit (LInt a)]) => integer a
      | ("integer_to_int", [Lit (LInteger a)]) => int a
      | ("char_ord", [Lit (LChar c)]) => SOME (lit (LInt (IntInf.fromInt c)))
      | ("char_chr", [Lit (LInt i)]) =>
          if IntInf.>= (i, zero) andalso IntInf.<= (i, IntInf.fromInt 1114111) then SOME (lit (LChar (IntInf.toInt i))) else NONE
      | ("double_from_int", [Lit (LInt i)]) => if bits i <= 53 then SOME (lit (LDouble (decimal i ^ ".0"))) else NONE
      | ("float_from_int", [Lit (LInt i)]) => if bits i <= 24 then SOME (lit (LFloat (decimal i ^ ".0"))) else NONE
      | ("double_encode", [Lit (LInt m), Lit (LInt e)]) =>
          if IntInf.abs e > IntInf.fromInt 2000 then NONE
          else Option.map (lit o LDouble) (encodeText (53, m, IntInf.toInt e))
      | ("float_encode", [Lit (LInt m), Lit (LInt e)]) =>
          if IntInf.abs e > IntInf.fromInt 2000 then NONE
          else Option.map (lit o LFloat) (encodeText (24, m, IntInf.toInt e))
      | ("str_size", [Lit (LStr s)]) => SOME (lit (LInt (IntInf.fromInt (String.size s))))
      | ("str_eq", [Lit (LStr a), Lit (LStr b)]) => SOME (bool (a = b))
      | ("str_concat", [Lit (LStr a), Lit (LStr b)]) => SOME (lit (LStr (a ^ b)))
      | _ =>
          case after "int_" of
            SOME op' => arith' (op', int, ints)
          | NONE =>
              case after "integer_" of
                SOME p' => arith' (p', integer, integers)
              | NONE =>
                  case after "char_" of
                    SOME c =>
                      (case c of
                         "eq" => chars (ccompare (op =))
                       | "ne" => chars (ccompare (op <>))
                       | "lt" => chars (ccompare (op <))
                       | "le" => chars (ccompare (op <=))
                       | "gt" => chars (ccompare (op >))
                       | "ge" => chars (ccompare (op >=))
                       | _ => NONE)
                  | NONE => NONE
    end

  (* the arithmetic and comparisons of the integer primitives op, their
     result made by mk, their arguments taken by over *)
  and arith' (op' : string, mk : IntInf.int -> exp option, over : (IntInf.int * IntInf.int -> exp option) -> exp option) =
    let
      fun divide f (a, b) = if b = zero then NONE else mk (f (a, b))
      fun compare c (a, b) = SOME (bool (c (a, b)))
    in
      case op' of
        "add" => over (fn (a, b) => mk (IntInf.+ (a, b)))
      | "sub" => over (fn (a, b) => mk (IntInf.- (a, b)))
      | "mul" => over (fn (a, b) => mk (IntInf.* (a, b)))
      | "quot" => over (divide IntInf.quot)
      | "rem" => over (divide IntInf.rem)
      | "div" => over (divide IntInf.div)
      | "mod" => over (divide IntInf.mod)
      | "eq" => over (compare (op =))
      | "ne" => over (compare (op <>))
      | "lt" => over (compare IntInf.<)
      | "le" => over (compare IntInf.<=)
      | "gt" => over (compare IntInf.>)
      | "ge" => over (compare IntInf.>=)
      | _ => NONE
    end

  (* ---- fromInteger and fromRational at the Prelude's instances ---- *)

  (* the program's library's Prelude, as its entities' keys begin *)
  fun prelude () = CoreSimplifyBase.libraryEntity (#prelude, "")

  (* the Prelude's instance of class cls at the Prelude's type t, as
     desugaring names it (HsDsEnv.dfunName) *)
  fun instanceOf (cls, t) = "%inst:" ^ prelude () ^ cls ^ "@" ^ prelude () ^ t

  (* `literal (f, ty, dict, arg)` is the literal `f @ty dict arg` gives,
     where f is the Prelude's fromInteger or fromRational, dict the Prelude's
     instance at Double or Float, and arg an Integer literal or a ratio of
     two, known as `ratio` gives it *)
  fun literal (f : string, dict : string, arg : atom, ratio : string -> (IntInf.int * IntInf.int) option) : exp option =
    let
      val double = f = prelude () ^ "fromInteger" andalso dict = instanceOf ("Num", "Double")
                   orelse f = prelude () ^ "fromRational" andalso dict = instanceOf ("Fractional", "Double")
      val float = f = prelude () ^ "fromInteger" andalso dict = instanceOf ("Num", "Float")
                  orelse f = prelude () ^ "fromRational" andalso dict = instanceOf ("Fractional", "Float")
      val value =
        if not (double orelse float) then NONE
        else
          case (f = prelude () ^ "fromInteger", arg) of
            (true, Lit (LInteger n)) => if bits n <= (if double then 53 else 24) then SOME (decimal n ^ ".0") else NONE
          | (false, Var r) => (case ratio r of SOME (n, d) => exactText (n, d) | NONE => NONE)
          | _ => NONE
    in
      case value of
        SOME text => SOME (lit (if double then LDouble text else LFloat text))
      | NONE => NONE
    end
end

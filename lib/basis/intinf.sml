(* IntInf: arbitrary precision integers implemented in SML on top of the
   64-bit int. A value is a sign and a little-endian list of base-2^30 limbs
   without high zero limbs; zero is never negative. The representation is
   therefore canonical and structural equality is value equality.

   This file is compiled before int.sml (Int.toLarge/fromLarge use it), so it
   relies on the builtin overloaded operators and VM primitives only. Every
   helper that uses int arithmetic is defined before the IntInf operators
   shadow + - * div mod ~ < <= > >= inside the structure. *)
structure IntInf =
struct
  type limb = int                       (* below, `int` means IntInf.int *)
  datatype int = I of bool * limb list  (* negative?, limbs *)

  val base : limb = 1073741824          (* 2^30: limb products stay below 2^60 *)

  val intQuot = _prim "int_quot" : limb * limb -> limb
  val intRem = _prim "int_rem" : limb * limb -> limb
  val intToString = _prim "int_to_string" : limb -> string
  val strSize = _prim "string_size" : string -> limb
  val strConcat = _prim "string_concat_list" : string list -> string
  val explode = _prim "string_explode" : string -> char list
  val ord = _prim "char_ord" : char -> limb

  (* ---- magnitudes: little-endian limb lists without high zeros ---- *)

  fun norm ds =
    let fun drop (0 :: r) = drop r | drop r = r
    in List.rev (drop (List.rev ds)) end

  fun cmpMag (a, b) =
    let
      val la = List.length a and lb = List.length b
      fun go ([], []) = EQUAL
        | go (x :: xs, y :: ys) = if x < y then LESS else if x > y then GREATER else go (xs, ys)
        | go _ = EQUAL
    in if la < lb then LESS else if la > lb then GREATER else go (List.rev a, List.rev b) end

  fun addMag (a, b) =
    let
      fun go ([], [], 0) = []
        | go ([], [], c) = [c]
        | go (x :: xs, [], c) = let val s = x + c in (s mod base) :: go (xs, [], s div base) end
        | go ([], ys, c) = go (ys, [], c)
        | go (x :: xs, y :: ys, c) = let val s = x + y + c in (s mod base) :: go (xs, ys, s div base) end
    in go (a, b, 0) end

  (* requires a >= b *)
  fun subMag (a, b) =
    let
      fun go ([], [], _) = []
        | go (x :: xs, [], bw) = let val d = x - bw in if d < 0 then (d + base) :: go (xs, [], 1) else d :: go (xs, [], 0) end
        | go (x :: xs, y :: ys, bw) = let val d = x - y - bw in if d < 0 then (d + base) :: go (xs, ys, 1) else d :: go (xs, ys, 0) end
        | go ([], _, _) = raise Fail "IntInf.subMag"
    in norm (go (a, b, 0)) end

  (* 0 <= d < base *)
  fun mulSmall (a, d) =
    let
      fun go ([], 0) = []
        | go ([], c) = [c]
        | go (x :: xs, c) = let val p = x * d + c in (p mod base) :: go (xs, p div base) end
    in if d = 0 then [] else go (a, 0) end

  fun addSmall (a, d) = if d = 0 then a else addMag (a, [d])

  fun shiftLimbs (0, ds) = ds
    | shiftLimbs (n, ds) = 0 :: shiftLimbs (n - 1, ds)

  (* The product of a zero (no limbs) and b must have no limbs either: a
     shifted empty partial product is a list of zero limbs. *)
  fun mulMag ([], _) = []
    | mulMag (a, b) =
    let
      fun go ([], _, acc) = acc
        | go (y :: ys, shift, acc) =
          let val part = if y = 0 then [] else shiftLimbs (shift, mulSmall (a, y))
          in go (ys, shift + 1, addMag (acc, part)) end
    in go (b, 0, []) end

  (* 0 < d < base; returns (quotient, remainder) *)
  fun divModSmall (a, d) =
    let
      fun go ([], r, acc) = (norm acc, r)
        | go (x :: xs, r, acc) = let val cur = r * base + x in go (xs, cur mod d, (cur div d) :: acc) end
    in go (List.rev a, 0, []) end

  (* b nonempty; base-2^30 long division, each quotient limb found by binary search *)
  fun divModMag (a, b) =
    case cmpMag (a, b) of
      LESS => ([], a)
    | _ =>
      (case b of
         [d] => let val (q, r) = divModSmall (a, d) in (q, if r = 0 then [] else [r]) end
       | _ =>
         let
           fun go ([], r, acc) = (norm acc, r)
             | go (x :: xs, r, acc) =
               let
                 val r' = norm (x :: r)
                 fun search (lo, hi) =
                   if hi - lo <= 1 then lo
                   else
                     let val mid = (lo + hi) div 2
                     in case cmpMag (mulSmall (b, mid), r') of GREATER => search (lo, mid) | _ => search (mid, hi) end
                 val q = search (0, base)
               in go (xs, subMag (r', mulSmall (b, q)), q :: acc) end
         in go (List.rev a, [], []) end)

  (* ---- signed values ---- *)

  fun make (neg, mag) = case mag of [] => I (false, []) | _ => I (neg, mag)
  val zero = I (false, [])
  val one = I (false, [1])
  fun isZero (I (_, mag)) = List.null mag

  fun fromInt (n : limb) =
    if n = 0 then zero
    else if n > 0 then
      let fun go 0 = [] | go m = intRem (m, base) :: go (intQuot (m, base)) in I (false, go n) end
    else
      let fun go 0 = [] | go m = (0 - intRem (m, base)) :: go (intQuot (m, base)) in I (true, go n) end

  (* raises Overflow through the checked int arithmetic *)
  fun toInt (I (neg, mag)) : limb =
    let fun go ([], acc) = acc
          | go (d :: ds, acc) = go (ds, if neg then acc * base - d else acc * base + d)
    in go (List.rev mag, 0) end

  fun negI (I (neg, mag)) = make (not neg, mag)
  fun absI (I (_, mag)) = I (false, mag)

  fun addI (I (na, ma), I (nb, mb)) =
    if na = nb then make (na, addMag (ma, mb))
    else
      case cmpMag (ma, mb) of
        LESS => make (nb, subMag (mb, ma))
      | _ => make (na, subMag (ma, mb))
  fun subI (a, b) = addI (a, negI b)
  fun mulI (I (na, ma), I (nb, mb)) = make (na <> nb, mulMag (ma, mb))

  (* truncating division: the remainder has the sign of the dividend *)
  fun quotRemI (I (na, ma), I (nb, mb)) =
    case mb of
      [] => raise Div
    | _ => let val (q, r) = divModMag (ma, mb) in (make (na <> nb, q), make (na, r)) end

  (* floor division *)
  fun divModI (a as I (na, _), b as I (nb, _)) =
    let val (q, r) = quotRemI (a, b)
    in if isZero r orelse na = nb then (q, r) else (subI (q, one), addI (r, b)) end

  fun compare (I (na, ma), I (nb, mb)) =
    if na <> nb then (if na then LESS else GREATER)
    else if na then cmpMag (mb, ma)
    else cmpMag (ma, mb)

  fun sign (I (neg, mag)) : limb = if List.null mag then 0 else if neg then 0 - 1 else 1

  fun toString (I (neg, mag)) =
    case mag of
      [] => "0"
    | _ =>
      let
        val chunk = 1000000000
        fun chunks (m, acc) = if List.null m then acc else let val (q, r) = divModSmall (m, chunk) in chunks (q, r :: acc) end
        fun zerosThen (k, acc) = if k <= 0 then acc else zerosThen (k - 1, "0" :: acc)
        fun render (_, []) = []
          | render (first, c :: cs) =
            let val s = intToString c
                val piece = if first then s else strConcat (zerosThen (9 - strSize s, [s]))
            in piece :: render (false, cs) end
        val pieces = render (true, chunks (mag, []))
      in strConcat (if neg then "~" :: pieces else pieces) end

  fun fromString s =
    let
      fun isSpace c = c = #" " orelse (ord c >= 9 andalso ord c <= 13)
      fun isDigit c = ord c >= 48 andalso ord c <= 57
      fun skip (c :: cs) = if isSpace c then skip cs else c :: cs
        | skip [] = []
      val cs = skip (explode s)
      val (neg, cs) =
        case cs of
          c :: rest => if c = #"~" orelse c = #"-" then (true, rest) else if c = #"+" then (false, rest) else (false, cs)
        | [] => (false, [])
      fun digits (c :: cs, mag, any) =
          if isDigit c then digits (cs, addSmall (mulSmall (mag, 10), ord c - 48), true) else (mag, any)
        | digits ([], mag, any) = (mag, any)
      val (mag, any) = digits (cs, [], false)
    in if any then SOME (make (neg, mag)) else NONE end

  fun pow (x as I (neg, mag), n : limb) =
    if n < 0 then
      (case mag of
         [] => raise Div
       | [1] => if neg andalso intRem (n, 2) <> 0 then x else one
       | _ => zero)
    else
      let fun go (b, e, acc) = if e = 0 then acc else go (mulI (b, b), e div 2, if e mod 2 = 1 then mulI (acc, b) else acc)
      in go (x, n, one) end

  (* ---- the public operators (shadowing the int ones from here on) ---- *)

  val precision : limb option = NONE
  val minInt : int option = NONE
  val maxInt : int option = NONE
  val toLarge = fn (x : int) => x
  val fromLarge = fn (x : int) => x

  val op + = addI
  val op - = subI
  val op * = mulI
  val ~ = negI
  val abs = absI
  val quotRem = quotRemI
  val divMod = divModI
  val quot = fn (a, b) => #1 (quotRemI (a, b))
  val rem = fn (a, b) => #2 (quotRemI (a, b))
  val op div = fn (a, b) => #1 (divModI (a, b))
  val op mod = fn (a, b) => #2 (divModI (a, b))
  val op < = fn (a, b) => compare (a, b) = LESS
  val op <= = fn (a, b) => compare (a, b) <> GREATER
  val op > = fn (a, b) => compare (a, b) = GREATER
  val op >= = fn (a, b) => compare (a, b) <> LESS
  fun min (a, b) = if compare (a, b) = GREATER then b else a
  fun max (a, b) = if compare (a, b) = LESS then b else a
  fun sameSign (a, b) = sign a = sign b
end

structure LargeInt = IntInf

(* Integer constants and the overloaded operators at IntInf.int. A constant
   is converted from its digits where it is evaluated. *)
structure RuneIntInf =
struct
  fun fromLit (digits : string) : IntInf.int =
    case IntInf.fromString digits of
      SOME i => i
    | NONE => raise Fail "RuneIntInf.fromLit"
end

_overload int IntInf via RuneIntInf.fromLit

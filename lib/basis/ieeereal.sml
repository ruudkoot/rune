(* IEEEReal: the types of IEEE arithmetic that do not depend on a precision.

   Implements: IEEE_REAL *)
structure IEEEReal =
struct
  exception Unordered
  datatype real_order = LESS | EQUAL | GREATER | UNORDERED
  datatype float_class = NAN | INF | ZERO | NORMAL | SUBNORMAL
  datatype rounding_mode = TO_NEAREST | TO_NEGINF | TO_POSINF | TO_ZERO

  local
    val setRound = _prim "real_set_round" : int -> unit
    val getRound = _prim "real_get_round" : unit -> int
    val intToString = _prim "int_to_string" : int -> string
  in
    fun setRoundingMode TO_NEAREST = setRound 0
      | setRoundingMode TO_NEGINF = setRound 1
      | setRoundingMode TO_POSINF = setRound 2
      | setRoundingMode TO_ZERO = setRound 3
    fun getRoundingMode () =
      case getRound () of 1 => TO_NEGINF | 2 => TO_POSINF | 3 => TO_ZERO | _ => TO_NEAREST

    (* sign * 0.d1d2...dn * 10^exp *)
    type decimal_approx = {class : float_class, sign : bool, digits : int list, exp : int}

    fun toString ({class, sign, digits, exp} : decimal_approx) =
      let
        fun digit d = chr (48 + d)
        val body =
          case class of
            ZERO => "0.0"
          | INF => "inf"
          | NAN => "nan"
          | _ => "0." ^ implode (map digit digits) ^ (if exp = 0 then "" else "E" ^ intToString exp)
      in if sign then "~" ^ body else body end

    (* [+~-]?([0-9]+(.[0-9]+)? | .[0-9]+)((e|E)[+~-]?[0-9]+)?, or
       [+~-]?(inf | infinity | nan) in any case. The numeral is kept as digit
       lists, so that no digit is lost: scanNumeral is what Real.scan uses too. *)
    fun scanNumeral (getc : (char, 'a) StringCvt.reader) src =
      let
        fun isDigit c = #"0" <= c andalso c <= #"9"
        fun lower c = if #"A" <= c andalso c <= #"Z" then chr (ord c + 32) else c
        fun digits (src, acc) =
          case getc src of
            SOME (c, rest) => if isDigit c then digits (rest, (ord c - 48) :: acc) else (rev acc, src)
          | NONE => (rev acc, src)
        fun word ([], src) = SOME src
          | word (w :: ws, src) =
            (case getc src of SOME (c, rest) => if lower c = w then word (ws, rest) else NONE | NONE => NONE)
        val src = StringCvt.skipWS getc src
        val (sign, src) =
          case getc src of
            SOME (#"~", rest) => (true, rest)
          | SOME (#"-", rest) => (true, rest)
          | SOME (#"+", rest) => (false, rest)
          | _ => (false, src)
        (* the exponent, if a complete one is next *)
        fun exponent src =
          case getc src of
            SOME (c, rest) =>
              if c = #"e" orelse c = #"E" then
                let
                  val (negative, rest') =
                    case getc rest of
                      SOME (#"~", r) => (true, r)
                    | SOME (#"-", r) => (true, r)
                    | SOME (#"+", r) => (false, r)
                    | _ => (false, rest)
                in
                  case digits (rest', []) of
                    ([], _) => (NONE, src)
                  | (ds, after) => (SOME (negative, ds), after)
                end
              else (NONE, src)
          | NONE => (NONE, src)
        fun number (il, fl, src) =
          let val (e, rest) = exponent src
          in SOME ({sign = sign, special = NONE, il = il, fl = fl, exponent = e}, rest) end
        fun special (name, rest) =
          SOME ({sign = sign, special = SOME name, il = [], fl = [], exponent = NONE}, rest)
      in
        case digits (src, []) of
          ([], _) =>
            (case getc src of
               SOME (#".", rest) =>
                 (case digits (rest, []) of
                    ([], _) => NONE
                  | (fl, after) => number ([], fl, after))
             | _ =>
                 (case word ([#"i", #"n", #"f"], src) of
                    SOME rest =>
                      (case word ([#"i", #"n", #"i", #"t", #"y"], rest) of
                         SOME rest' => special ("inf", rest')
                       | NONE => special ("inf", rest))
                  | NONE =>
                      (case word ([#"n", #"a", #"n"], src) of
                         SOME rest => special ("nan", rest)
                       | NONE => NONE)))
        | (il, after) =>
            (case getc after of
               SOME (#".", rest) =>
                 (case digits (rest, []) of
                    ([], _) => number (il, [], after)
                  | (fl, after') => number (il, fl, after'))
             | _ => number (il, [], after))
      end

    fun scan getc src =
      case scanNumeral getc src of
        NONE => NONE
      | SOME ({sign, special = SOME "inf", ...}, rest) =>
          SOME ({class = INF, sign = sign, digits = [], exp = 0} : decimal_approx, rest)
      | SOME ({sign, special = SOME _, ...}, rest) =>
          SOME ({class = NAN, sign = sign, digits = [], exp = 0}, rest)
      | SOME ({sign, il, fl, exponent, ...}, rest) =>
          let
            fun dropZeros (0 :: ds) = dropZeros ds
              | dropZeros ds = ds
            fun countZeros (0 :: ds, n) = countZeros (ds, n + 1)
              | countZeros (_, n) = n
            fun dropTrailing ds = rev (dropZeros (rev ds))
            (* the scanned exponent; one that does not fit an int is as good as the largest *)
            val e =
              case exponent of
                NONE => 0
              | SOME (negative, ds) =>
                  let
                    fun value ([], acc) = acc
                      | value (d :: ds, acc) = value (ds, if acc > 100000000 then acc else acc * 10 + d)
                    val v = value (ds, 0)
                  in if negative then ~ v else v end
            val il = dropZeros il
            val fl = dropTrailing fl
          in
            case (il, fl) of
              ([], []) => SOME ({class = ZERO, sign = sign, digits = [], exp = 0}, rest)
            | ([], _) =>
                let val m = countZeros (fl, 0)
                in SOME ({class = NORMAL, sign = sign, digits = dropZeros fl, exp = e - m}, rest) end
            | _ => SOME ({class = NORMAL, sign = sign, digits = dropTrailing (il @ fl), exp = length il + e}, rest)
          end

    fun fromString s = StringCvt.scanString scan s
  end
end

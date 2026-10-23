(* Implements: C_CONST *)
structure CConst : C_CONST =
struct
  type value = {integer : IntInf.int, unsigned : bool}
  exception Error of CLex.location * string
  fun error (t : CLex.token) s = raise Error (CLex.diagnostic (t, s))
  fun power n = IntInf.<< (1, Word.fromInt n)
  fun limits width = if width < 8 orelse width > 128 then raise Domain
                     else (power width, power (width - 1))
  fun digit c = if Char.isDigit c then SOME (Char.ord c - Char.ord #"0")
    else if Char.contains "abcdefABCDEF" c then SOME (Char.ord (Char.toLower c) - Char.ord #"a" + 10) else NONE
  fun literal {width, token = t : CLex.token} =
    let val (modulus, sign) = limits width
        val text = #text t
        val n = size text
        fun at i = String.sub (text, i)
        fun number (base, start) =
          let fun go (i, value, count) =
                if i < n then case digit (at i) of
                    SOME d => if d < base then
                                let val next = value * IntInf.fromInt base + IntInf.fromInt d
                                in if next >= modulus then error t "integer literal out of range"
                                   else go (i + 1, next, count + 1) end
                              else finish (i, value, count)
                  | NONE => finish (i, value, count)
                else finish (i, value, count)
              and finish (i, value, count) =
                let val suffix = String.map Char.toLower (String.extract (text, i, NONE))
                    val unsigned = String.isSubstring "u" suffix orelse (base <> 10 andalso value >= sign)
                    val () = if count > 0 andalso List.exists (fn s => s = suffix)
                      ["", "u", "l", "ul", "lu", "ll", "ull", "llu", "i64", "ui64", "i64u"] then () else error t "invalid C integer literal"
                    val () = if value < modulus andalso (unsigned orelse value < sign) then () else error t "integer literal out of range"
                in {integer = value, unsigned = unsigned} end
          in go (start, 0, 0) end
        fun character () =
          let val first = case CharVector.findi (fn (_, c) => c = #"'") text of SOME (i, _) => i + 1
                | NONE => error t "invalid character literal"
              val () = if first < n andalso at (n - 1) = #"'" then () else error t "unterminated character literal"
              val body = String.substring (text, first, n - first - 1)
              fun digits base s =
                let fun go ([], a) = a
                      | go (c :: cs, a) = case digit c of SOME d =>
                          if d < base andalso a * base + d <= 255 then go (cs, a * base + d)
                          else error t "invalid or out-of-range character escape"
                        | NONE => error t "invalid character escape"
                in go (String.explode s, 0) end
              val value = if size body = 1 then Char.ord (String.sub (body, 0))
                else if String.isPrefix "\\" body then
                  case String.extract (body, 1, NONE) of
                    "n" => 10 | "r" => 13 | "t" => 9 | "v" => 11 | "a" => 7 | "b" => 8 | "f" => 12
                  | "\\" => 92 | "'" => 39 | "\"" => 34 | "?" => 63
                  | s => if String.isPrefix "x" s andalso size s > 1 then digits 16 (String.extract (s, 1, NONE))
                         else if size s <= 3 andalso CharVector.all (fn c => Char.contains "01234567" c) s then digits 8 s
                         else error t "unsupported character escape"
                else error t "multicharacter constant is implementation-defined"
          in if value <= 255 then {integer = IntInf.fromInt value, unsigned = false}
             else error t "wide character constant requires target encoding" end
    in if #kind t = CLex.CharacterLiteral then character ()
       else if String.isPrefix "0x" text orelse String.isPrefix "0X" text then number (16, 2)
       else if String.isPrefix "0b" text orelse String.isPrefix "0B" text then number (2, 2)
       else if n > 1 andalso at 0 = #"0" then number (8, 0) else number (10, 0) end
  datatype expression = Literal of CLex.token | Name of CLex.token
    | Unary of CLex.token * expression | Binary of CLex.token * expression * expression
    | Conditional of expression * expression * expression
  fun evaluate {width, lookup, tokens} =
    let
      val tokens = List.filter (fn (t : CLex.token) => #kind t <> CLex.Newline) tokens
      val fallback : CLex.location = {file = "<constant>", line = 1, column = 1}
      fun missing () = raise Error (case rev tokens of t :: _ => #location t | [] => fallback, "incomplete constant expression")
      fun rank s = case s of "||" => 1 | "&&" => 2 | "|" => 3 | "^" => 4 | "&" => 5
        | "==" => 6 | "!=" => 6 | "<" => 7 | ">" => 7 | "<=" => 7 | ">=" => 7
        | "<<" => 8 | ">>" => 8 | "+" => 9 | "-" => 9 | "*" => 10 | "/" => 10 | "%" => 10 | _ => 0
      fun primary [] = missing ()
        | primary ((t : CLex.token) :: rest) =
          if #text t = "(" then
            let val (e, tail) = conditional rest
            in case tail of close :: after => if #text close = ")" then (e, after) else error close "expected ')'"
              | [] => missing () end
          else if List.exists (fn s => s = #text t) ["+", "-", "!", "~"] then
            let val (e, tail) = primary rest in (Unary (t, e), tail) end
          else if #kind t = CLex.Number orelse #kind t = CLex.CharacterLiteral then (Literal t, rest)
          else if #kind t = CLex.Identifier then (Name t, rest) else error t "expected integer constant"
      and binary minimum input =
        let val (left, rest) = primary input
            fun more (left, (t : CLex.token) :: tail) =
                  if rank (#text t) < minimum then (left, t :: tail)
                  else let val (right, after) = binary (rank (#text t) + 1) tail
                       in more (Binary (t, left, right), after) end
              | more pair = pair
        in more (left, rest) end
      and conditional input =
        let val (condition, rest) = binary 1 input
        in case rest of q :: tail => if #text q = "?" then
             let val (yes, after) = conditional tail
             in case after of colon :: tail => if #text colon = ":" then
                  let val (no, rest) = conditional tail in (Conditional (condition, yes, no), rest) end
                  else error colon "expected ':'" | [] => missing () end
           else (condition, rest) | [] => (condition, rest) end
      val (tree, rest) = conditional tokens
      val () = case rest of [] => () | t :: _ => error t "unexpected constant-expression token"
      val (modulus, sign) = limits width
      fun truth ({integer, ...} : value) = integer <> 0
      fun bool b : value = {integer = if b then 1 else 0, unsigned = false}
      fun bits n = IntInf.mod (n, modulus)
      fun result t unsigned n : value =
        if unsigned then {integer = bits n, unsigned = true}
        else if n >= ~sign andalso n < sign then {integer = n, unsigned = false}
        else error t "signed constant-expression overflow"
      fun signedBits n = let val b = bits n in if b >= sign then b - modulus else b end
      (* Conditional conversions depend on both operand types even though
         only one branch's arithmetic is evaluated. *)
      fun unsigned (Literal t) = #unsigned (literal {width = width, token = t})
        | unsigned (Name t) = (case lookup (#text t) of SOME v => #unsigned v | NONE => error t "unresolved constant")
        | unsigned (Unary (t, e)) = #text t <> "!" andalso unsigned e
        | unsigned (Binary (t, a, b)) = if List.exists (fn s => s = #text t)
            ["==", "!=", "<", ">", "<=", ">=", "&&", "||"] then false
          else if #text t = "<<" orelse #text t = ">>" then unsigned a else unsigned a orelse unsigned b
        | unsigned (Conditional (_, a, b)) = unsigned a orelse unsigned b
      fun eval (Literal t) = literal {width = width, token = t}
        | eval (Name t) = (case lookup (#text t) of SOME v => v | NONE => error t "unresolved constant")
        | eval (Unary (t, e)) =
          let val {integer = n, unsigned = u} = eval e
          in case #text t of "+" => result t u n | "-" => result t u (~n)
             | "!" => bool (n = 0) | _ => result t u (if u then bits (IntInf.notb n) else signedBits (IntInf.notb n)) end
        | eval (Conditional (c, a, b)) =
          let val v = eval (if truth (eval c) then a else b)
              val u = unsigned a orelse unsigned b
          in {integer = if u then bits (#integer v) else #integer v, unsigned = u} end
        | eval (Binary (t, a, b)) =
          if #text t = "&&" then bool (truth (eval a) andalso truth (eval b))
          else if #text t = "||" then bool (truth (eval a) orelse truth (eval b))
          else
            let val va = eval a and vb = eval b
                val u = #unsigned va orelse #unsigned vb
                val x = if u then bits (#integer va) else #integer va
                val y = if u then bits (#integer vb) else #integer vb
                fun divide remainder = if y = 0 then error t "division by zero in constant expression"
                  else if not u andalso x = ~sign andalso y = ~1 then error t "signed constant-expression overflow"
                  else if remainder then result t u (IntInf.rem (x, y)) else result t u (IntInf.quot (x, y))
                fun bit f = let val n = f (bits x, bits y) in result t u (if u then n else signedBits n) end
                fun shift left =
                  if #integer vb < 0 orelse #integer vb >= IntInf.fromInt width then error t "invalid constant shift"
                  else let val count = Word.fromInt (IntInf.toInt (#integer vb))
                           val n = #integer va
                       in if left then (if n < 0 then error t "left shift of negative constant" else result t (#unsigned va) (IntInf.<< (n, count)))
                          else result t (#unsigned va) (IntInf.~>> (n, count)) end
            in case #text t of "+" => result t u (x + y) | "-" => result t u (x - y) | "*" => result t u (x * y)
             | "/" => divide false | "%" => divide true | "&" => bit IntInf.andb | "|" => bit IntInf.orb | "^" => bit IntInf.xorb
             | "<<" => shift true | ">>" => shift false | "==" => bool (x = y) | "!=" => bool (x <> y)
             | "<" => bool (x < y) | ">" => bool (x > y) | "<=" => bool (x <= y) | ">=" => bool (x >= y)
             | _ => error t "unsupported constant operator" end
      fun validate (Literal t) = ignore (literal {width = width, token = t})
        | validate (Name t) = (case lookup (#text t) of SOME _ => () | NONE => error t "unresolved constant")
        | validate (Unary (_, e)) = validate e
        | validate (Binary (_, a, b)) = (validate a; validate b)
        | validate (Conditional (c, a, b)) = (validate c; validate a; validate b)
    in validate tree; eval tree end
end

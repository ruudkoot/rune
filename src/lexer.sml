structure Lexer =
struct
  datatype kind = Word of string | Number of IntInf.int | Text of string
                | Symbol of string | EOF
  type token = kind * Source.pos
  val deferred = String.tokens Char.isSpace
    "rec and as with datatype abstype withtype case of exception raise handle ref while do type eqtype local open infix infixr nonfix op structure struct signature sig functor sharing where include o before nil NONE SOME LESS EQUAL GREATER Bind Match Chr Div Domain Empty Fail Option Overflow Size Span Subscript"
  val symbols = "!%&$#+-/:<=>?@\\~`^|*"
  fun scan input =
    let
      val size = String.size input
      val index = ref 0
      val line = ref 1
      val column = ref 1
      fun pos () = {line = !line, column = !column}
      fun peek n = if !index + n < size then SOME (String.sub (input, !index+n)) else NONE
      fun take () =
        let val c = String.sub (input, !index)
        in index := !index+1;
           if c = #"\n" then (line := !line+1; column := 1) else column := !column+1;
           c
        end
      fun bad p msg = Source.fail p "lex" msg
      fun eat () = ignore (take ())
      fun consume pred =
        let val first = !index
            fun loop () = case peek 0 of SOME c => if pred c then (eat (); loop ()) else () | NONE => ()
        in loop (); String.substring (input, first, !index-first) end
      fun comment p depth =
        if depth = 0 then ()
        else case (peek 0, peek 1) of
          (NONE, _) => bad p "unterminated comment"
        | (SOME #"(", SOME #"*") => (eat (); eat (); comment p (depth+1))
        | (SOME #"*", SOME #")") => (eat (); eat (); comment p (depth-1))
        | _ => (eat (); comment p depth)
      fun space () = case (peek 0, peek 1) of
          (SOME #"(", SOME #"*") =>
            let val p = pos () in eat (); eat (); comment p 1; space () end
        | (SOME c, _) => if Char.isSpace c then (eat (); space ()) else ()
        | _ => ()
      fun string p =
        let
          fun escaped () = case peek 0 of
              NONE => bad p "unterminated string escape"
            | SOME c =>
              if Char.isDigit c then
                let fun digit () = case peek 0 of SOME d =>
                          if Char.isDigit d then (eat (); Char.ord d - 48)
                          else bad (pos ()) "decimal escape needs three digits"
                        | NONE => bad p "incomplete decimal escape"
                    val a = digit ()
                    val b = digit ()
                    val c = digit ()
                    val n = a*100+b*10+c
                in if n > 255 then bad p "decimal escape exceeds 255" else SOME (Char.chr n) end
              else if Char.isSpace c then
                (ignore (consume Char.isSpace);
                 case peek 0 of SOME #"\\" => (eat (); NONE)
                   | _ => bad (pos ()) "string gap must end with backslash")
              else (eat (); case c of
                  #"a" => SOME (Char.chr 7) | #"b" => SOME (Char.chr 8)
                | #"t" => SOME #"\t" | #"n" => SOME #"\n"
                | #"v" => SOME (Char.chr 11) | #"f" => SOME #"\f"
                | #"r" => SOME #"\r" | #"\\" => SOME #"\\" | #"\"" => SOME #"\""
                | #"^" => (case peek 0 of SOME d =>
                    if Char.ord d >= 64 andalso Char.ord d <= 95
                    then (eat (); SOME (Char.chr (Char.ord d-64)))
                    else bad (pos ()) "invalid control escape"
                  | NONE => bad p "incomplete control escape")
                | _ => bad (pos ()) "unknown string escape")
          fun loop chars = case peek 0 of
              NONE => bad p "unterminated string"
            | SOME #"\"" => (eat (); String.implode (List.rev chars))
            | SOME #"\\" => (eat (); case escaped () of NONE => loop chars | SOME c => loop (c::chars))
            | SOME c => if Char.ord c < 32 orelse Char.ord c = 127
                        then bad (pos ()) "unescaped control character in string"
                        else (eat (); loop (c::chars))
        in eat (); loop [] end
      fun identifier () =
        let fun rest c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"
            val first = consume rest
            fun parts acc = case (peek 0, peek 1) of
                (SOME #".", SOME c) => if Char.isAlpha c then
                  (eat (); parts (acc ^ "." ^ consume rest)) else acc
              | _ => acc
        in parts first end
      fun number p =
        let val negative = peek 0 = SOME #"~"
            val () = if negative then eat () else ()
            val digits = consume Char.isDigit
            val () = case peek 0 of SOME c =>
                 if Char.isAlpha c orelse c = #"." then
                   Source.fail p "unsupported" "only decimal integer literals are supported"
                 else () | NONE => ()
            val n = valOf (IntInf.fromString ((if negative then "~" else "") ^ digits))
        in Number (Source.intRange p n) end
      fun next () =
        let val () = space ()
            val p = pos ()
        in (case peek 0 of
            NONE => EOF
          | SOME c =>
            if Char.isAlpha c then
              let val word = identifier ()
              in if List.exists (fn s => s = word) deferred
                 then Source.fail p "unsupported" ("'" ^ word ^ "' is not supported")
                 else Word word end
            else if Char.isDigit c orelse
              (c = #"~" andalso (case peek 1 of SOME d => Char.isDigit d | NONE => false))
              then number p
            else if c = #"\"" then Text (string p)
            else if List.exists (fn d => c = d) [#"(", #")", #";", #"_", #","]
              then (eat (); Symbol (String.str c))
            else if Char.contains symbols c then
              let val s = consume (Char.contains symbols)
              in if List.exists (fn x => x = s)
                   ["~", "+", "-", "*", "^", "=", "=>", "<>", "<", "<=", ">", ">="]
                 then Symbol s
                 else Source.fail p "unsupported" ("operator '" ^ s ^ "' is not supported") end
            else Source.fail p "unsupported" ("unexpected or unsupported character '" ^ String.str c ^ "'"), p)
        end
      fun loop acc count =
        if count > Source.maxCount then Source.fail (pos ()) "limit" "too many tokens"
        else let val t as (k, _) = next ()
             in case k of EOF => List.rev (t::acc) | _ => loop (t::acc) (count+1) end
    in if size > Source.maxSource then Source.fail Source.start "limit" "source exceeds 1 MiB"
       else loop [] 0 end
end

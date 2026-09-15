(* Converts source characters into tokens while keeping syntax concerns out
 * of the parser. *)
signature RUNE_LEXER =
sig
  datatype token =
      TInt of int | TIdent of string | TTrue | TFalse
    | TPlus | TMinus | TStar | TSlash | TEq | TNe | TLt | TLe | TGt | TGe
    | TIf | TThen | TElse | TLet | TVal | TIn | TEnd | TSemi
    | TLParen | TRParen | TEOF
  val lex : string -> token list
end

structure RuneLexer : RUNE_LEXER =
struct
  datatype token =
      TInt of int | TIdent of string | TTrue | TFalse
    | TPlus | TMinus | TStar | TSlash | TEq | TNe | TLt | TLe | TGt | TGe
    | TIf | TThen | TElse | TLet | TVal | TIn | TEnd | TSemi
    | TLParen | TRParen | TEOF

  fun isAlpha c = Char.isAlpha c orelse c = #"_"
  fun isAlphaNum c = isAlpha c orelse Char.isDigit c

  fun lex source =
    let
      val n = size source
      fun word i =
        if i >= n orelse not (isAlphaNum (String.sub (source, i))) then i
        else word (i + 1)
      fun number i =
        if i >= n orelse not (Char.isDigit (String.sub (source, i))) then i
        else number (i + 1)
      fun scan i =
        if i >= n then [TEOF]
        else
          let val c = String.sub (source, i)
          in
            if Char.isSpace c then scan (i + 1)
            else if Char.isDigit c then
              let
                val j = number i
                val text = String.substring (source, i, j - i)
              in
                (case Int.fromString text of
                    SOME value => TInt value
                  | NONE => raise Fail "invalid integer") :: scan j
              end
            else if isAlpha c then
              let
                val j = word i
                val text = String.substring (source, i, j - i)
                val token =
                  case text of
                      "true" => TTrue
                    | "false" => TFalse
                    | "if" => TIf
                    | "then" => TThen
                    | "else" => TElse
                    | "let" => TLet
                    | "val" => TVal
                    | "in" => TIn
                    | "end" => TEnd
                    | _ => TIdent text
              in token :: scan j end
            else
              case c of
                  #"+" => TPlus :: scan (i + 1)
                | #"-" => TMinus :: scan (i + 1)
                | #"*" => TStar :: scan (i + 1)
                | #"/" => TSlash :: scan (i + 1)
                | #"(" => TLParen :: scan (i + 1)
                | #")" => TRParen :: scan (i + 1)
                | #";" => TSemi :: scan (i + 1)
                | #"=" => TEq :: scan (i + 1)
                | #"<" =>
                    if i + 1 < n andalso String.sub (source, i + 1) = #"=" then
                      TLe :: scan (i + 2)
                    else if i + 1 < n andalso String.sub (source, i + 1) = #">" then
                      TNe :: scan (i + 2)
                    else TLt :: scan (i + 1)
                | #">" =>
                    if i + 1 < n andalso String.sub (source, i + 1) = #"=" then
                      TGe :: scan (i + 2)
                    else TGt :: scan (i + 1)
                | _ => raise Fail "invalid character"
          end
    in
      scan 0
    end
end

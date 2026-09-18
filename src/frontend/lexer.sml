(* Hand-written lexer for Standard ML '97. Produces a vector of tokens so the
   parser can backtrack cheaply. *)
structure Lexer =
struct
  open Token

  type item = token * Source.span

  fun isSymbolic c = Char.contains "!%&$#+-/:<=>?@\\~`^|*" c
  fun isIdentStart c = Char.isAlpha c
  fun isIdentChar c = Char.isAlphaNum c orelse c = #"'" orelse c = #"_"
  fun isHex c = Char.isHexDigit c

  fun hexVal c =
    if Char.isDigit c then Char.ord c - Char.ord #"0"
    else Char.ord (Char.toLower c) - Char.ord #"a" + 10

  fun tokenize (file : Source.file) : item vector =
    let
      val text = #text file
      val name = #name file
      val n = String.size text
      fun span (a, b) : Source.span = {file = name, start = a, stop = b}
      fun err (a, b, msg) = Error.error (span (a, b), msg)
      fun ch i = if i < n then String.sub (text, i) else #"\000"
      fun at i = i < n

      fun skipComment (i, depth, start) =
        if i >= n then err (start, start + 2, "unterminated comment")
        else if ch i = #"(" andalso ch (i + 1) = #"*" then skipComment (i + 2, depth + 1, start)
        else if ch i = #"*" andalso ch (i + 1) = #")" then
          (if depth = 1 then i + 2 else skipComment (i + 2, depth - 1, start))
        else skipComment (i + 1, depth, start)

      fun digitsWhile (i, p) = if at i andalso p (ch i) then digitsWhile (i + 1, p) else i

      (* Explicit IntInf operations: Rune has no literal overloading. *)
      fun parseInt (s, radix : int) : IntInf.int =
        let
          val r = IntInf.fromInt radix
          fun go (i, acc) =
            if i >= String.size s then acc
            else go (i + 1, IntInf.+ (IntInf.* (acc, r), IntInf.fromInt (hexVal (String.sub (s, i)))))
        in go (0, IntInf.fromInt 0) end

      (* Lex a numeric literal starting at i (after an optional ~ at negStart). *)
      fun lexNumber (start, i, neg) =
        let
          fun finishInt (j, v) =
            (INT (if neg then IntInf.~ v else v), span (start, j), j)
        in
          if ch i = #"0" andalso ch (i + 1) = #"w" andalso not neg
             andalso (Char.isDigit (ch (i + 2)) orelse (ch (i + 2) = #"x" andalso isHex (ch (i + 3)))) then
            (if ch (i + 2) = #"x" then
               let val j = digitsWhile (i + 3, isHex)
               in (WORD (parseInt (String.substring (text, i + 3, j - i - 3), 16)), span (start, j), j) end
             else
               let val j = digitsWhile (i + 2, Char.isDigit)
               in (WORD (parseInt (String.substring (text, i + 2, j - i - 2), 10)), span (start, j), j) end)
          else if ch i = #"0" andalso ch (i + 1) = #"x" andalso isHex (ch (i + 2)) then
            let val j = digitsWhile (i + 2, isHex)
            in finishInt (j, parseInt (String.substring (text, i + 2, j - i - 2), 16)) end
          else
            let
              val j = digitsWhile (i, Char.isDigit)
              val isReal = (ch j = #"." andalso Char.isDigit (ch (j + 1)))
                           orelse ((ch j = #"e" orelse ch j = #"E")
                                   andalso (Char.isDigit (ch (j + 1))
                                            orelse (ch (j + 1) = #"~" andalso Char.isDigit (ch (j + 2)))))
            in
              if isReal then
                let
                  val j1 = if ch j = #"." then digitsWhile (j + 1, Char.isDigit) else j
                  val j2 =
                    if (ch j1 = #"e" orelse ch j1 = #"E") then
                      let val k = if ch (j1 + 1) = #"~" then j1 + 2 else j1 + 1
                      in if Char.isDigit (ch k) then digitsWhile (k, Char.isDigit) else j1 end
                    else j1
                in (REAL (String.substring (text, start, j2 - start)), span (start, j2), j2) end
              else finishInt (j, parseInt (String.substring (text, i, j - i), 10))
            end
        end

      (* Lex the body of a string literal starting after the opening quote.
         Returns (chars, index after closing quote). *)
      fun lexStringBody (start, i, acc) =
        if i >= n orelse ch i = #"\n" then err (start, i, "unterminated string literal")
        else
          case ch i of
            #"\"" => (String.implode (List.rev acc), i + 1)
          | #"\\" => lexEscape (start, i + 1, acc)
          | c => if Char.ord c < 32 then err (i, i + 1, "control character in string literal")
                 else lexStringBody (start, i + 1, c :: acc)
      and lexEscape (start, i, acc) =
        let fun cont c = lexStringBody (start, i + 1, c :: acc)
        in
          case ch i of
            #"a" => cont #"\a" | #"b" => cont #"\b" | #"t" => cont #"\t"
          | #"n" => cont #"\n" | #"v" => cont #"\v" | #"f" => cont #"\f"
          | #"r" => cont #"\r" | #"\\" => cont #"\\" | #"\"" => cont #"\""
          | #"^" =>
            let val c = ch (i + 1)
            in if Char.ord c >= 64 andalso Char.ord c <= 95 then
                 lexStringBody (start, i + 2, Char.chr (Char.ord c - 64) :: acc)
               else err (i - 1, i + 2, "invalid control escape in string literal")
            end
          | #"u" =>
            if isHex (ch (i + 1)) andalso isHex (ch (i + 2)) andalso isHex (ch (i + 3)) andalso isHex (ch (i + 4)) then
              let val v = IntInf.toInt (parseInt (String.substring (text, i + 1, 4), 16))
              in if v > 255 then err (i - 1, i + 5, "\\u escape out of range for 8-bit strings")
                 else lexStringBody (start, i + 5, Char.chr v :: acc)
              end
            else err (i - 1, i + 1, "invalid \\u escape")
          | c =>
            if Char.isDigit c then
              (if Char.isDigit (ch (i + 1)) andalso Char.isDigit (ch (i + 2)) then
                 let val v = IntInf.toInt (parseInt (String.substring (text, i, 3), 10))
                 in if v > 255 then err (i - 1, i + 3, "\\ddd escape out of range")
                    else lexStringBody (start, i + 3, Char.chr v :: acc)
                 end
               else err (i - 1, i + 1, "invalid numeric escape"))
            else if Char.isSpace c then
              (* string gap: \ whitespace \ *)
              let fun skip j =
                    if j >= n then err (start, j, "unterminated string gap")
                    else if ch j = #"\\" then lexStringBody (start, j + 1, acc)
                    else if Char.isSpace (ch j) then skip (j + 1)
                    else err (j, j + 1, "invalid character in string gap")
              in skip i end
            else err (i - 1, i + 1, "invalid escape sequence")
        end

      fun lexSymbolic (i, j) = if at j andalso isSymbolic (ch j) then lexSymbolic (i, j + 1) else j

      fun lookupReserved (s, tbl) =
        case List.find (fn (k, _) => k = s) tbl of SOME (_, t) => SOME t | NONE => NONE

      (* Alphanumeric identifier or long identifier. *)
      fun lexAlpha (i) =
        let
          val j = digitsWhile (i, isIdentChar)
          val s = String.substring (text, i, j - i)
        in
          case lookupReserved (s, reserved) of
            SOME t => (t, span (i, j), j)
          | NONE =>
            if ch j = #"." andalso (isIdentStart (ch (j + 1)) orelse isSymbolic (ch (j + 1))) then
              lexLong (i, [s], j + 1)
            else (ID s, span (i, j), j)
        end
      and lexLong (start, path, i) =
        if isIdentStart (ch i) then
          let
            val j = digitsWhile (i, isIdentChar)
            val s = String.substring (text, i, j - i)
          in
            if isSome (lookupReserved (s, reserved)) then err (i, j, "reserved word in long identifier")
            else if ch j = #"." andalso (isIdentStart (ch (j + 1)) orelse isSymbolic (ch (j + 1))) then
              lexLong (start, s :: path, j + 1)
            else (LONGID (List.rev path, s), span (start, j), j)
          end
        else
          let
            val j = lexSymbolic (i, i)
            val s = String.substring (text, i, j - i)
          in
            if j = i orelse isSome (lookupReserved (s, reservedSymbolic)) then
              err (start, j, "malformed long identifier")
            else (LONGID (List.rev path, s), span (start, j), j)
          end

      fun next (i) : (token * Source.span * int) =
        if i >= n then (EOF, span (n, n), n)
        else
          let val c = ch i
          in
            if Char.isSpace c then next (i + 1)
            else if c = #"(" andalso ch (i + 1) = #"*" then next (skipComment (i + 2, 1, i))
            else if Char.isDigit c then lexNumber (i, i, false)
            else if c = #"~" andalso Char.isDigit (ch (i + 1))
                    andalso not (ch (i + 1) = #"0" andalso ch (i + 2) = #"w") then
              lexNumber (i, i + 1, true)
            else if isIdentStart c then lexAlpha i
            else if c = #"'" then
              (* Section 2.4: a type variable is an alphanumeric identifier starting with a prime *)
              let val j = digitsWhile (i + 1, isIdentChar)
              in (TYVAR (String.substring (text, i, j - i)), span (i, j), j) end
            else if c = #"\"" then
              let val (s, j) = lexStringBody (i, i + 1, [])
              in (STRING s, span (i, j), j) end
            else if c = #"#" andalso ch (i + 1) = #"\"" then
              let val (s, j) = lexStringBody (i, i + 2, [])
              in if String.size s <> 1 then err (i, j, "character literal must contain exactly one character")
                 else (CHAR (String.sub (s, 0)), span (i, j), j)
              end
            else if c = #"_" then
              (if String.size text >= i + 5 andalso String.substring (text, i, 5) = "_prim"
                  andalso not (isIdentChar (ch (i + 5))) then (PRIM, span (i, i + 5), i + 5)
               else (UNDERSCORE, span (i, i + 1), i + 1))
            else if c = #"." then
              (if ch (i + 1) = #"." andalso ch (i + 2) = #"." then (DOTS, span (i, i + 3), i + 3)
               else err (i, i + 1, "unexpected '.'"))
            else if isSymbolic c then
              let
                val j = lexSymbolic (i, i)
                val s = String.substring (text, i, j - i)
              in
                case lookupReserved (s, reservedSymbolic) of
                  SOME t => (t, span (i, j), j)
                | NONE => (ID s, span (i, j), j)
              end
            else
              let
                val t =
                  case c of
                    #"(" => LPAREN | #")" => RPAREN | #"[" => LBRACKET | #"]" => RBRACKET
                  | #"{" => LBRACE | #"}" => RBRACE | #"," => COMMA | #";" => SEMI
                  | _ => err (i, i + 1, "unexpected character '" ^ Char.toString c ^ "'")
              in (t, span (i, i + 1), i + 1) end
          end

      fun loop (i, acc) =
        let val (t, sp, j) = next i
        in case t of EOF => List.rev ((t, sp) :: acc) | _ => loop (j, (t, sp) :: acc) end
    in
      Vector.fromList (loop (0, []))
    end
end

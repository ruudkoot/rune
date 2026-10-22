(* Implements: C_LEX *)
structure CLex : C_LEX =
struct
  type location = {file : string, line : int, column : int}
  datatype kind = Identifier | Number | StringLiteral | CharacterLiteral | Punctuation | Newline
  type token = {kind : kind, text : string, space : bool, location : location, origins : location list}
  exception Error of location * string
  fun diagnostic (t : token, message) =
    let fun place ({file, line, column} : location) = file ^ ":" ^ Int.toString line ^ ":" ^ Int.toString column
    in case #origins t of [] => (#location t, message)
      | outer :: rest => (outer, message ^ String.concat (List.map (fn p => "\n  expanded from " ^ place p) (rest @ [#location t]))) end
  fun scan {file, text} =
    let
      val n = size text
      fun at i = String.sub (text, i)
      fun phaseOne i =
        if i + 2 < n andalso at i = #"?" andalso at (i + 1) = #"?" then
          case at (i + 2) of
            #"=" => (#"#", 3) | #"/" => (#"\\", 3) | #"'" => (#"^", 3)
          | #"(" => (#"[", 3) | #")" => (#"]", 3) | #"!" => (#"|", 3)
          | #"<" => (#"{", 3) | #">" => (#"}", 3) | #"-" => (#"~", 3)
          | _ => (at i, 1)
        else (at i, 1)
      (* Phase two removes backslash-newline before tokens or comments.
         A parallel vector retains each remaining byte's physical position. *)
      fun splice (i, line, column, chars, places) =
        if i = n then (String.implode (rev chars), Vector.fromList (rev places),
                       {file = file, line = line, column = column})
        else let val (c, advance) = phaseOne i
                 val next = i + advance
                 val pos = {file = file, line = line, column = column}
             in if c = #"\\" andalso next < n andalso at next = #"\n" then
                  splice (next + 1, line + 1, 1, chars, places)
                else if c = #"\\" andalso next + 1 < n andalso at next = #"\r" andalso at (next + 1) = #"\n" then
                  splice (next + 2, line + 1, 1, chars, places)
                else splice (next, if c = #"\n" then line + 1 else line,
                        if c = #"\n" then 1 else column + advance, c :: chars, pos :: places) end
      val (source, positions, eof) = splice (0, 1, 1, [], [])
      val limit = size source
      fun ch i = String.sub (source, i)
      fun loc i = if i < limit then Vector.sub (positions, i) else eof
      fun fail i message = raise Error (loc i, message)
      fun starts i s = i + size s <= limit andalso String.substring (source, i, size s) = s
      fun ident c = Char.isAlphaNum c orelse c = #"_" orelse c = #"$" orelse Char.ord c >= 128
      fun start c = Char.isAlpha c orelse c = #"_" orelse c = #"$" orelse Char.ord c >= 128
      fun take pred i = if i < limit andalso pred (ch i) then take pred (i + 1) else i
      fun block (first, i) =
        if i + 1 >= limit then fail first "unterminated block comment"
        else if starts i "*/" then i + 2 else block (first, i + 1)
      fun literal (first, quote, i) =
        if i >= limit then fail first "unterminated literal"
        else if ch i = quote then i + 1
        else if ch i = #"\n" orelse ch i = #"\r" then fail i "newline in literal"
        else if ch i = #"\\" then
          if i + 1 < limit then literal (first, quote, i + 2) else fail first "unterminated escape"
        else literal (first, quote, i + 1)
      fun number i =
        if i >= limit then i
        else if ident (ch i) orelse ch i = #"." then number (i + 1)
        else if i > 0 andalso (ch i = #"+" orelse ch i = #"-") andalso
          Char.contains "eEpP" (ch (i - 1)) then number (i + 1)
        else i
      val punct = ["%:%:", ">>=", "<<=", "...", "->", "++", "--", "<<", ">>", "<=", ">=", "==", "!=",
                   "&&", "||", "*=", "/=", "%=", "+=", "-=", "&=", "^=", "|=", "##", "<:", ":>", "<%", "%>", "%:"]
      fun token (kind, i, j, space) : token =
        {kind = kind, text = String.substring (source, i, j - i), space = space, location = loc i, origins = []}
      fun loop (i, space, acc) =
        if i >= limit then rev acc
        else if i = 0 andalso starts i "\239\187\191" then loop (3, true, acc)
        else if ch i = #"\n" then loop (i + 1, true, token (Newline, i, i + 1, space) :: acc)
        else if Char.isSpace (ch i) then loop (i + 1, true, acc)
        else if starts i "//" then loop (take (fn c => c <> #"\n") (i + 2), true, acc)
        else if starts i "/*" then loop (block (i, i + 2), true, acc)
        else
          let
            val prefix = if starts i "u8\"" then 2
              else if i + 1 < limit andalso Char.contains "LuU" (ch i) andalso
                (ch (i + 1) = #"\"" orelse ch (i + 1) = #"'") then 1 else 0
            val (kind, j) =
              if ch (i + prefix) = #"\"" orelse ch (i + prefix) = #"'" then
                (if ch (i + prefix) = #"\"" then StringLiteral else CharacterLiteral,
                 literal (i, ch (i + prefix), i + prefix + 1))
              else if start (ch i) then (Identifier, take ident (i + 1))
              else if Char.isDigit (ch i) orelse (ch i = #"." andalso i + 1 < limit andalso Char.isDigit (ch (i + 1))) then
                (Number, number (i + 1))
              else case List.find (starts i) punct of SOME s => (Punctuation, i + size s)
                (* C preprocessing tokens include any remaining nonblank
                   source character. Inactive SDK annotation macros use
                   bare backslashes; reject them only if a declaration
                   actually contains one after preprocessing. *)
                | NONE => if Char.ord (ch i) >= 32 then (Punctuation, i + 1)
                          else fail i ("invalid preprocessing byte " ^ Int.toString (Char.ord (ch i)))
          in loop (j, false, token (kind, i, j, space) :: acc) end
    in loop (0, true, []) end
  fun spelling tokens = String.concat (List.map (fn (t : token) => if #kind t = Newline then "\n" else #text t ^ " ") tokens)
end

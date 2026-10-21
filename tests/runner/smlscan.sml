(* Lexical inspection of generated SML metadata. This is deliberately a
   small independent scanner, not the compiler's parser: strings and nested
   comments cannot introduce dependencies into a law or a signature check. *)
structure SmlScan =
struct
  exception Bad of string
  datatype kind = Identifier | Symbol | Literal
  type token = {text : string, kind : kind, start : int, finish : int, line : int, column : int}
  fun tokens text =
    let
      val n = size text
      fun at i = String.sub (text, i)
      fun pair (i, a, b) = i + 1 < n andalso at i = a andalso at (i + 1) = b
      fun word c = Char.isAlphaNum c orelse c = #"_" orelse c = #"'"
      fun operator c = Char.contains "!%&$#+-/:<=>?@\\~`^|*" c
      fun until predicate i = if i < n andalso predicate (at i) then until predicate (i + 1) else i
      fun comment (i, depth) =
        if i >= n then raise Bad "unterminated SML comment"
        else if pair (i, #"(", #"*") then comment (i + 2, depth + 1)
        else if pair (i, #"*", #")") then if depth = 1 then i + 2 else comment (i + 2, depth - 1)
        else comment (i + 1, depth)
      fun literal i =
        if i >= n then raise Bad "unterminated SML string"
        else if at i = #"\"" then i + 1
        else if at i = #"\\" then
          if i + 1 >= n then raise Bad "unterminated SML escape"
          else if Char.isSpace (at (i + 1)) then
            let val stop = until Char.isSpace (i + 1)
            in if stop < n andalso at stop = #"\\" then literal (stop + 1) else raise Bad "unterminated SML string gap" end
          else literal (i + 2)
        else literal (i + 1)
      fun position (i, stop, line, column) =
        if i = stop then (line, column)
        else if at i = #"\n" then position (i + 1, stop, line + 1, 1) else position (i + 1, stop, line, column + 1)
      fun loop (i, line, column, acc) =
        if i = n then List.rev acc else
          let
            val (stop, token) =
              if Char.isSpace (at i) then (until Char.isSpace i, NONE)
              else if pair (i, #"(", #"*") then (comment (i + 2, 1), NONE)
              else
                let val (stop, kind) = if at i = #"\"" then (literal (i + 1), Literal)
                      else if word (at i) then (until word i, Identifier)
                      else if operator (at i) then (until operator i, Symbol)
                      else (i + 1, Symbol)
                in (stop, SOME {text = String.substring (text, i, stop - i), kind = kind, start = i,
                                finish = stop, line = line, column = column}) end
            val (nextLine, nextColumn) = position (i, stop, line, column)
          in loop (stop, nextLine, nextColumn, case token of NONE => acc | SOME t => t :: acc) end
    in loop (0, 1, 1, []) end
  fun code text = List.map #text (List.filter (fn {kind, ...} : token => kind <> Literal) (tokens text))
  fun upper s = size s > 0 andalso Char.isUpper (String.sub (s, 0))
  fun dotted (head, "." :: name :: rest) =
        if upper name then dotted (head @ [name], rest) else (head, "." :: name :: rest)
    | dotted (head, rest) = (head, rest)
  fun opens text =
    let
      fun names ("in" :: rest, acc) = SOME (List.rev acc, rest)
        | names (name :: rest, acc) =
            if upper name then let val (path, rest) = dotted ([name], rest)
                              in names (rest, String.concatWith "." path :: acc) end else NONE
        | names _ = NONE
      fun loop ("let" :: "open" :: rest, acc) =
            (case names (rest, []) of SOME (found, rest) => loop (rest, List.revAppend (found, acc)) | NONE => loop (rest, acc))
        | loop (_ :: rest, acc) = loop (rest, acc)
        | loop ([], acc) = List.rev acc
    in loop (code text, []) end
  fun qualified text =
    let
      fun chain (path, "." :: name :: rest) =
            if upper name then chain (path @ [name], rest)
            else (String.concatWith "." path, rest)
        | chain (path, rest) =
            if length path > 1 then (String.concatWith "." (List.take (path, length path - 1)), rest) else ("", rest)
      fun loop (name :: "." :: next :: rest, acc) =
            if upper name then let val (path, rest) = chain ([name], "." :: next :: rest)
                              in loop (rest, if path = "" then acc else path :: acc) end
            else loop ("." :: next :: rest, acc)
        | loop (_ :: rest, acc) = loop (rest, acc)
        | loop ([], acc) = List.rev acc
    in loop (code text, []) end
end

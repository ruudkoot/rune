(* Markdown as GitHub renders it: what has to be escaped so that the text of
   a comment stays text, and the blocks and tables the pages are made of. *)
structure DocMarkdown =
struct
  structure T = DocText

  (* Text that Markdown must not read: every character that could begin
     markup is escaped, and so is what would turn the start of a line into a
     list, a heading, a quotation or a rule. *)
  fun escape (s : string) : string =
    let
      val n = String.size s
      fun special c = Char.contains "\\*_<>[]`|#~$" c
      (* at the start of a line: "- ", "+ ", "12. ", "12) ", "===", "---" *)
      fun lineStart i =
        let
          fun digits j = if j < n andalso Char.isDigit (String.sub (s, j)) then digits (j + 1) else j
          val c = String.sub (s, i)
        in
          if (c = #"-" orelse c = #"+" orelse c = #"=") then true
          else if Char.isDigit c then
            let val j = digits i
            in j < n andalso (String.sub (s, j) = #"." orelse String.sub (s, j) = #")") end
          else false
        end
      fun go (i, atStart, acc) =
        if i >= n then String.concat (List.rev acc)
        else
          let val c = String.sub (s, i)
          in
            if c = #"\n" then go (i + 1, true, "\n" :: acc)
            else if atStart andalso c = #" " then go (i + 1, true, " " :: acc)
            else if c = #"&" then go (i + 1, false, "&amp;" :: acc)
            else if special c then go (i + 1, false, String.str c :: "\\" :: acc)
            else if atStart andalso lineStart i then
              (if Char.isDigit c then
                 (* escape the full stop or the parenthesis after the digits *)
                 let
                   fun digits j = if j < n andalso Char.isDigit (String.sub (s, j)) then digits (j + 1) else j
                   val j = digits i
                 in go (j + 1, false, String.str (String.sub (s, j)) :: "\\" :: String.substring (s, i, j - i) :: acc) end
               else go (i + 1, false, String.str c :: "\\" :: acc))
            else go (i + 1, false, String.str c :: acc)
          end
    in
      go (0, true, [])
    end

  (* Text inside <pre> and other HTML. *)
  fun escapeHtml (s : string) : string =
    String.translate (fn #"&" => "&amp;" | #"<" => "&lt;" | #">" => "&gt;" | c => String.str c) s

  (* Code between backquotes; GitHub needs more backquotes around code that
     has one inside. *)
  fun code (c : string) : string =
    if CharVector.exists (fn ch => ch = #"`") c then "`` " ^ c ^ " ``" else "`" ^ c ^ "`"

  (* link: where a piece of code that is a reference leads, if anywhere. *)
  fun inline (link : string -> string option) (i : T.inline) : string =
    case i of
      T.Text t => escape t
    | T.Code c => (case link c of SOME href => "[" ^ code c ^ "](" ^ href ^ ")" | NONE => code c)
    | T.Url u => "<" ^ u ^ ">"

  fun inlines link (is : T.inline list) : string = String.concat (List.map (inline link) is)

  (* The same on one line, for a table cell or a heading: a bar is escaped
     inside code as well, which GitHub's tables want. *)
  fun cell link (is : T.inline list) : string =
    let
      val s = String.translate (fn #"\n" => " " | c => String.str c) (inlines link is)
      (* escape the bars that `escape` has not: those inside code *)
      fun bars (i, acc) =
        if i >= String.size s then String.concat (List.rev acc)
        else if String.sub (s, i) = #"\\" andalso i + 1 < String.size s then
          bars (i + 2, String.substring (s, i, 2) :: acc)
        else if String.sub (s, i) = #"|" then bars (i + 1, "\\|" :: acc)
        else bars (i + 1, String.str (String.sub (s, i)) :: acc)
    in
      bars (0, [])
    end

  fun fenced (language : string, c : string) : string = "```" ^ language ^ "\n" ^ c ^ "\n```\n\n"

  (* The blocks that need no decision: paragraphs, code and lists. A reserved
     paragraph is the caller's. *)
  fun block link (b : T.block) : string =
    case b of
      T.Para is => inlines link is ^ "\n\n"
    | T.CodeBlock c => fenced ("sml", c)
    | T.Bullets items =>
        String.concat (List.map (fn is =>
                                   "- " ^ String.concatWith "\n  " (String.fields (fn c => c = #"\n") (inlines link is)) ^ "\n")
                                items) ^ "\n"
    | T.Reserved _ => ""

  fun table (header : string list, rows : string list list) : string =
    let fun row cells = "| " ^ String.concatWith " | " cells ^ " |\n"
    in
      row header ^ row (List.map (fn _ => "---") header) ^ String.concat (List.map row rows) ^ "\n"
    end

  fun anchor (name : string) : string = "<a name=\"" ^ name ^ "\"></a>"
end

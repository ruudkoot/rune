(* Markdown: CommonMark's blocks and inlines, GitHub's tables, HTML and
   documents.

   The blocks are found line by line, containers (block quotes, list
   items) by the lines they hold; the inlines by CommonMark's algorithm of
   delimiters and brackets ("Appendix: A parsing strategy").

   Implements: MARKDOWN *)
structure Markdown :> MARKDOWN =
struct
  datatype inline =
      Text of string
    | Code of string
    | Emphasis of inline list
    | Strong of inline list
    | Link of {target : string, title : string option, text : inline list}
    | Image of {source : string, title : string option, alt : inline list}
    | Html of string
    | SoftBreak
    | HardBreak

  datatype alignment = Default | Left | Center | Right

  datatype block =
      Heading of int * inline list
    | Paragraph of inline list
    | CodeBlock of {info : string, text : string}
    | HtmlBlock of string
    | Quote of block list
    | List of {ordered : bool, start : int, tight : bool, items : block list list}
    | Table of {align : alignment list, header : inline list list, rows : inline list list list}
    | Rule

  datatype role = Head of int | Mono | Italic | Bold | Anchor of string | Quoted | Marker | Ruler

  (* ------------------------------------------------------------ text *)

  fun isSpaceTab c = c = #" " orelse c = #"\t"
  fun isWhite c = c = #" " orelse c = #"\t" orelse c = #"\n" orelse c = #"\r" orelse c = #"\012" orelse c = #"\011"
  fun isBlank s = CharVector.all isSpaceTab s
  fun lead s = let fun go i = if i < size s andalso String.sub (s, i) = #" " then go (i + 1) else i in go 0 end
  fun dropSpaces (s, n) = let fun go (i, k) = if k > 0 andalso i < size s andalso String.sub (s, i) = #" " then go (i + 1, k - 1) else i
                          in String.extract (s, go (0, n), NONE) end
  fun trimLeft s = let fun go i = if i < size s andalso isWhite (String.sub (s, i)) then go (i + 1) else i
                   in String.extract (s, go 0, NONE) end
  fun trimRight s = let fun go i = if i > 0 andalso isWhite (String.sub (s, i - 1)) then go (i - 1) else i
                    in String.substring (s, 0, go (size s)) end
  fun trim s = trimLeft (trimRight s)
  fun startsWith (s, i, t) = i + size t <= size s andalso String.substring (s, i, size t) = t
  fun lower s = String.map Char.toLower s
  fun contains (s, t) = String.isSubstring t s
  fun count (s, i, c) = let fun go j = if j < size s andalso String.sub (s, j) = c then go (j + 1) else j in go i - i end

  (* Tabs in a line's indentation as spaces, to stops of 4. *)
  fun expandLead s =
    let
      fun go (i, col, acc) =
        if i < size s andalso String.sub (s, i) = #" " then go (i + 1, col + 1, #" " :: acc)
        else if i < size s andalso String.sub (s, i) = #"\t" then
          let val n = 4 - col mod 4 in go (i + 1, col + n, List.tabulate (n, fn _ => #" ") @ acc) end
        else String.implode (rev acc) ^ String.extract (s, i, NONE)
    in
      go (0, 0, [])
    end

  (* Tabs at the start of s as spaces, s beginning at column col. *)
  fun expandFrom (s, col) =
    let
      fun go (i, c, acc) =
        if i < size s andalso String.sub (s, i) = #" " then go (i + 1, c + 1, #" " :: acc)
        else if i < size s andalso String.sub (s, i) = #"\t" then
          let val n = 4 - c mod 4 in go (i + 1, c + n, List.tabulate (n, fn _ => #" ") @ acc) end
        else String.implode (rev acc) ^ String.extract (s, i, NONE)
    in
      go (0, col, [])
    end

  fun linesOf text =
    let
      val t = String.translate (fn #"\000" => "\239\191\189" | c => String.str c) text
      fun go (#"\r" :: #"\n" :: rest, acc) = go (rest, #"\n" :: acc)
        | go (#"\r" :: rest, acc) = go (rest, #"\n" :: acc)
        | go (c :: rest, acc) = go (rest, c :: acc)
        | go ([], acc) = String.implode (rev acc)
      val t = go (String.explode t, [])
      val ls = String.fields (fn c => c = #"\n") t
      val ls = if not (null ls) andalso List.last ls = "" then List.take (ls, List.length ls - 1) else ls
    in
      map expandLead ls
    end

  (* the line after at most three blanks of indentation *)
  fun body s = if lead s < 4 then SOME (String.extract (s, lead s, NONE)) else NONE

  (* ------------------------------------------------------------ entities *)

  fun named name =
    let
      val t = MarkdownEntities.table
      fun go (lo, hi) =
        if lo >= hi then NONE
        else
          let val mid = (lo + hi) div 2 val (n, v) = Vector.sub (t, mid)
          in case String.compare (name, n) of EQUAL => SOME v | LESS => go (lo, mid) | GREATER => go (mid + 1, hi) end
    in
      go (0, Vector.length t)
    end

  fun utf8 c = Utf8.encode (if c = 0 orelse not (Utf8.isScalar c) then 0xFFFD else c)

  (* an entity at i (s at i is &): its text and where it ends *)
  fun entity (s, i) =
    let
      fun scan (j, ok) = if j < size s andalso ok (String.sub (s, j)) then scan (j + 1, ok) else j
    in
      if startsWith (s, i, "&#x") orelse startsWith (s, i, "&#X") then
        let val j = scan (i + 3, Char.isHexDigit)
        in
          if j > i + 3 andalso j - (i + 3) <= 6 andalso j < size s andalso String.sub (s, j) = #";" then
            SOME (utf8 (valOf (StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i + 3, j - i - 3)))), j + 1)
          else NONE
        end
      else if startsWith (s, i, "&#") then
        let val j = scan (i + 2, Char.isDigit)
        in
          if j > i + 2 andalso j - (i + 2) <= 7 andalso j < size s andalso String.sub (s, j) = #";" then
            SOME (utf8 (valOf (Int.fromString (String.substring (s, i + 2, j - i - 2)))), j + 1)
          else NONE
        end
      else
        let val j = scan (i + 1, Char.isAlphaNum)
        in
          if j > i + 1 andalso j < size s andalso String.sub (s, j) = #";" then
            Option.map (fn v => (v, j + 1)) (named (String.substring (s, i + 1, j - i - 1)))
          else NONE
        end
    end

  (* backslash escapes and entities taken out of text that is not parsed
     further: a link's destination and title, a code block's info *)
  fun unescape s =
    let
      fun go (i, acc) =
        if i >= size s then String.concat (rev acc)
        else
          let val c = String.sub (s, i)
          in
            if c = #"\\" andalso i + 1 < size s andalso Char.isPunct (String.sub (s, i + 1)) then
              go (i + 2, String.str (String.sub (s, i + 1)) :: acc)
            else if c = #"&" then
              (case entity (s, i) of SOME (v, j) => go (j, v :: acc) | NONE => go (i + 1, "&" :: acc))
            else go (i + 1, String.str c :: acc)
          end
    in
      go (0, [])
    end

  (* ------------------------------------------------------------ HTML tags *)

  fun isTagChar c = Char.isAlphaNum c orelse c = #"-"

  (* an open tag or a closing tag at i: where it ends *)
  fun scanTag (s, i) =
    let
      val n = size s
      fun at j = if j < n then String.sub (s, j) else #"\000"
      fun spaces j = if j < n andalso isWhite (at j) then spaces (j + 1) else j
      fun name j = if Char.isAlpha (at j) then let fun go k = if isTagChar (at k) then go (k + 1) else k in SOME (go (j + 1)) end
                   else NONE
      fun attrName j =
        if Char.isAlpha (at j) orelse at j = #"_" orelse at j = #":" then
          let fun go k = if Char.isAlphaNum (at k) orelse Char.contains "_.:-" (at k) then go (k + 1) else k in SOME (go (j + 1)) end
        else NONE
      fun value j =
        case at j of
          #"\"" => let fun go k = if k >= n then NONE else if at k = #"\"" then SOME (k + 1) else go (k + 1) in go (j + 1) end
        | #"'" => let fun go k = if k >= n then NONE else if at k = #"'" then SOME (k + 1) else go (k + 1) in go (j + 1) end
        | _ => let fun go k = if k < n andalso not (isWhite (at k)) andalso not (Char.contains "\"'=<>`" (at k)) then go (k + 1) else k
                   val k = go j
               in if k > j then SOME k else NONE end
      fun attributes j =
        let val k = spaces j
        in
          if k > j then
            case attrName k of
              SOME e =>
                let val e' = spaces e
                in
                  if at e' = #"=" then
                    (case value (spaces (e' + 1)) of SOME v => attributes v | NONE => NONE)
                  else attributes e
                end
            | NONE => SOME k
          else SOME j
        end
    in
      if at i <> #"<" then NONE
      else if at (i + 1) = #"/" then
        case name (i + 2) of
          SOME j => let val k = spaces j in if at k = #">" then SOME (k + 1) else NONE end
        | NONE => NONE
      else
        case name (i + 1) of
          SOME j =>
            (case attributes j of
               SOME k =>
                 let val k = spaces k
                 in
                   if at k = #">" then SOME (k + 1)
                   else if at k = #"/" andalso at (k + 1) = #">" then SOME (k + 2)
                   else NONE
                 end
             | NONE => NONE)
        | NONE => NONE
    end

  val blockTags =
    ["address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center", "col", "colgroup",
     "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form", "frame",
     "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend", "li", "link",
     "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param", "search", "section",
     "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul"]

  (* the kind of HTML block a line begins (CommonMark's seven), or NONE *)
  fun htmlStart l =
    case body l of
      NONE => NONE
    | SOME t =>
        let
          val lt = lower t
          fun tagFollowed (k, names) =
            List.exists (fn nm => startsWith (lt, k, nm)
                                  andalso (k + size nm = size lt
                                           orelse Char.contains " \t>" (String.sub (lt, k + size nm))
                                           orelse startsWith (lt, k + size nm, "/>"))) names
        in
          if size t = 0 orelse String.sub (t, 0) <> #"<" then NONE
          else if tagFollowed (1, ["pre", "script", "style", "textarea"]) then SOME 1
          else if startsWith (t, 0, "<!--") then SOME 2
          else if startsWith (t, 0, "<?") then SOME 3
          else if size t > 2 andalso String.sub (t, 1) = #"!" andalso Char.isAlpha (String.sub (t, 2)) then SOME 4
          else if startsWith (t, 0, "<![CDATA[") then SOME 5
          else if tagFollowed (1, blockTags) orelse tagFollowed (2, blockTags) andalso startsWith (t, 0, "</") then SOME 6
          else
            case scanTag (t, 0) of
              SOME j => if isBlank (String.extract (t, j, NONE)) then SOME 7 else NONE
            | NONE => NONE
        end

  fun htmlEnds (kind, l) =
    let val ll = lower l
    in
      case kind of
        1 => contains (ll, "</pre>") orelse contains (ll, "</script>") orelse contains (ll, "</style>") orelse contains (ll, "</textarea>")
      | 2 => contains (l, "-->")
      | 3 => contains (l, "?>")
      | 4 => contains (l, ">")
      | 5 => contains (l, "]]>")
      | _ => false
    end

  (* ------------------------------------------------------------ block starts *)

  fun atx l =
    case body l of
      NONE => NONE
    | SOME t =>
        let val n = count (t, 0, #"#")
        in
          if n >= 1 andalso n <= 6 andalso (size t = n orelse isSpaceTab (String.sub (t, n))) then
            let
              val c = trimRight (trimLeft (String.extract (t, n, NONE)))
              fun hashes k = if k > 0 andalso String.sub (c, k - 1) = #"#" then hashes (k - 1) else k
              val k = hashes (size c)
              val c = if k = size c then c
                      else if k = 0 then ""
                      else if isSpaceTab (String.sub (c, k - 1)) then trimRight (String.substring (c, 0, k))
                      else c
            in
              SOME (n, c)
            end
          else NONE
        end

  fun thematic l =
    case body l of
      NONE => false
    | SOME t =>
        let val cs = List.filter (not o isSpaceTab) (String.explode t)
        in
          List.length cs >= 3 andalso Char.contains "*-_" (hd cs) andalso List.all (fn c => c = hd cs) cs
        end

  (* a fence: its character, its length, its indentation, its info *)
  fun fence l =
    case body l of
      NONE => NONE
    | SOME t =>
        if size t >= 3 andalso (String.sub (t, 0) = #"`" orelse String.sub (t, 0) = #"~") then
          let
            val c = String.sub (t, 0)
            val n = count (t, 0, c)
            val info = trim (String.extract (t, n, NONE))
          in
            if n >= 3 andalso not (c = #"`" andalso CharVector.exists (fn x => x = #"`") info)
            then SOME (c, n, lead l, info) else NONE
          end
        else NONE

  fun closesFence ((c, n, _, _), l) =
    case body l of
      NONE => false
    | SOME t => let val m = count (t, 0, c) in m >= n andalso isBlank (String.extract (t, m, NONE)) end

  fun setext l =
    case body l of
      NONE => NONE
    | SOME t =>
        let val t = trimRight t
        in
          if t <> "" andalso CharVector.all (fn c => c = #"=") t then SOME 1
          else if t <> "" andalso CharVector.all (fn c => c = #"-") t then SOME 2
          else NONE
        end

  fun quoteStart l = case body l of SOME t => size t > 0 andalso String.sub (t, 0) = #">" | NONE => false
  fun quoteRest l =
    let
      val t = valOf (body l)
      val r = expandFrom (String.extract (t, 1, NONE), lead l + 1)
    in
      if size r > 0 andalso String.sub (r, 0) = #" " then String.extract (r, 1, NONE) else r
    end

  datatype marker = Bullet of char | Ordered of char * int

  (* a list item's start: its marker, the column its content begins at,
     its first line's content, and whether that is empty *)
  fun listStart l =
    case body l of
      NONE => NONE
    | SOME t =>
        let
          val ind = lead l
          fun item (m, w) =
            let val after = expandFrom (String.extract (t, w, NONE), ind + w)
            in
              if after = "" orelse isBlank after then
                SOME {marker = m, indent = ind + w + 1, rest = "", empty = true}
              else if not (isSpaceTab (String.sub (after, 0))) then NONE
              else
                let val sp = lead after
                in
                  if sp >= 5 then SOME {marker = m, indent = ind + w + 1, rest = String.extract (after, 1, NONE), empty = false}
                  else SOME {marker = m, indent = ind + w + sp, rest = String.extract (after, sp, NONE), empty = false}
                end
            end
          val digits = let fun go j = if j < size t andalso Char.isDigit (String.sub (t, j)) then go (j + 1) else j in go 0 end
        in
          if size t > 0 andalso Char.contains "-+*" (String.sub (t, 0)) then item (Bullet (String.sub (t, 0)), 1)
          else if digits >= 1 andalso digits <= 9 andalso digits < size t andalso Char.contains ".)" (String.sub (t, digits)) then
            item (Ordered (String.sub (t, digits), valOf (Int.fromString (String.substring (t, 0, digits)))), digits + 1)
          else NONE
        end

  fun sameKind (Bullet a, Bullet b) = a = b
    | sameKind (Ordered (a, _), Ordered (b, _)) = a = b
    | sameKind _ = false

  (* a table's row as its cells, the pipes at its ends dropped, an
     escaped pipe kept *)
  fun cells l =
    let
      val t = trim l
      val t = if size t > 0 andalso String.sub (t, 0) = #"|" then String.extract (t, 1, NONE) else t
      val t = if size t > 0 andalso String.sub (t, size t - 1) = #"|"
                 andalso not (size t > 1 andalso String.sub (t, size t - 2) = #"\\")
              then String.substring (t, 0, size t - 1) else t
      fun go (i, cur, acc) =
        if i >= size t then rev (trim (String.implode (rev cur)) :: acc)
        else
          case String.sub (t, i) of
            #"\\" => if i + 1 < size t andalso String.sub (t, i + 1) = #"|" then go (i + 2, #"|" :: cur, acc)
                     else go (i + 1, #"\\" :: cur, acc)
          | #"|" => go (i + 1, [], trim (String.implode (rev cur)) :: acc)
          | c => go (i + 1, c :: cur, acc)
    in
      go (0, [], [])
    end

  fun delimiterRow l =
    let
      val cs = cells l
      fun align c =
        let
          val left = size c > 0 andalso String.sub (c, 0) = #":"
          val right = size c > 0 andalso String.sub (c, size c - 1) = #":"
          val dashes = String.substring (c, if left then 1 else 0, size c - (if left then 1 else 0) - (if right then 1 else 0))
                       handle Subscript => ""
        in
          if dashes <> "" andalso CharVector.all (fn x => x = #"-") dashes then
            SOME (case (left, right) of (true, true) => Center | (true, false) => Left | (false, true) => Right | _ => Default)
          else NONE
        end
      val aligns = map align cs
    in
      if CharVector.exists (fn c => c = #"|") l andalso List.all isSome aligns then SOME (map valOf aligns) else NONE
    end

  (* ------------------------------------------------------------ blocks *)

  (* the blocks before inlines are parsed: a paragraph or a heading is its
     text *)
  datatype raw =
      RHeading of int * string
    | RPara of string
    | RCode of {info : string, text : string}
    | RHtml of string
    | RQuote of raw list
    | RList of {ordered : bool, start : int, tight : bool, items : raw list list}
    | RTable of {align : alignment list, header : string list, rows : string list list}
    | RRule
    | RNothing      (* link reference definitions, which are no block *)

  (* the link reference definitions of the document, by normalised label *)
  val definitions : (string * (string * string option)) list ref = ref []

  (* the simple case folding of the scripts labels are written in: Latin,
     Greek and Cyrillic, and the sharp s as ss *)
  fun fold c =
    if c < 128 then [Char.ord (Char.toLower (Char.chr c))]
    else if c = 0xDF orelse c = 0x1E9E then [0x73, 0x73]
    else if (c >= 0xC0 andalso c <= 0xDE andalso c <> 0xD7) then [c + 0x20]
    else if c >= 0x100 andalso c <= 0x17F andalso c mod 2 = 0 andalso c <> 0x130 andalso c <> 0x138 then [c + 1]
    else if c >= 0x391 andalso c <= 0x3A9 andalso c <> 0x3A2 then [c + 0x20]
    else if c = 0x3C2 then [0x3C3]
    else if c >= 0x410 andalso c <= 0x42F then [c + 0x20]
    else if c >= 0x400 andalso c <= 0x40F then [c + 0x50]
    else [c]

  fun normalise label =
    String.concatWith " " (String.tokens isWhite (Utf8.implode (List.concat (map fold (Utf8.explode label)))))

  (* a line that ends a paragraph, as a block of its own begins *)
  fun interrupts l =
    isSome (atx l) orelse thematic l orelse isSome (fence l) orelse quoteStart l
    orelse (case htmlStart l of SOME k => k < 7 | NONE => false)
    orelse (case listStart l of
              SOME {empty = false, marker = Bullet _, ...} => true
            | SOME {empty = false, marker = Ordered (_, 1), ...} => true
            | _ => false)

  (* whether lines a container holds end inside a paragraph that a lazy
     line may continue *)
  fun endsInParagraph lines =
    let
      fun inFence ([], f) = isSome f
        | inFence (l :: rest, NONE) = inFence (rest, fence l)
        | inFence (l :: rest, SOME f) = if closesFence (f, l) then inFence (rest, NONE) else inFence (rest, SOME f)
      fun strip l =
        if quoteStart l then strip (quoteRest l)
        else case listStart l of SOME {rest, empty = false, ...} => strip rest | _ => l
    in
      case List.rev lines of
        [] => false
      | last :: _ =>
          not (isBlank last) andalso not (inFence (lines, NONE))
          andalso
            let val l = strip last
            in
              not (isBlank l) andalso lead l < 4 andalso not (isSome (atx l)) andalso not (thematic l)
              andalso not (isSome (fence l)) andalso not (isSome (htmlStart l))
            end
    end

  (* a lazy continuation line, which continues a paragraph as text: one
     that would underline a heading is escaped so as not to *)
  fun lazy l = if isSome (setext l) then "\\" ^ trimLeft l else l

  (* link reference definitions at the start of a paragraph's text: the
     definitions taken out and stored, and the text left *)
  fun takeDefinitions text =
    let
      val n = size text
      fun at j = if j < n then String.sub (text, j) else #"\000"
      fun spaces j = if j < n andalso isSpaceTab (at j) then spaces (j + 1) else j
      fun spacesNewline j = let val j = spaces j in if at j = #"\n" then spaces (j + 1) else j end
      fun label j =
        if at j <> #"[" then NONE
        else
          let
            fun go k =
              if k >= n orelse k - j > 1000 then NONE
              else case at k of
                     #"\\" => go (k + 2)
                   | #"[" => NONE
                   | #"]" => SOME k
                   | _ => go (k + 1)
          in
            case go (j + 1) of
              SOME k => let val l = String.substring (text, j + 1, k - j - 1)
                        in if trim l = "" then NONE else SOME (l, k + 1) end
            | NONE => NONE
          end
      fun destination j =
        if at j = #"<" then
          let fun go k = if k >= n orelse at k = #"\n" orelse at k = #"<" then NONE
                         else if at k = #"\\" then go (k + 2)
                         else if at k = #">" then SOME (String.substring (text, j + 1, k - j - 1), k + 1)
                         else go (k + 1)
          in go (j + 1) end
        else
          let
            fun go (k, depth) =
              if k >= n orelse Char.ord (at k) <= 32 then (k, depth)
              else case at k of
                     #"\\" => if k + 1 < n andalso Char.isPunct (at (k + 1)) then go (k + 2, depth) else go (k + 1, depth)
                   | #"(" => go (k + 1, depth + 1)
                   | #")" => if depth = 0 then (k, depth) else go (k + 1, depth - 1)
                   | _ => go (k + 1, depth)
            val (k, depth) = go (j, 0)
          in
            if k = j orelse depth <> 0 then NONE else SOME (String.substring (text, j, k - j), k)
          end
      fun title j =
        let
          val close = case at j of #"\"" => SOME #"\"" | #"'" => SOME #"'" | #"(" => SOME #")" | _ => NONE
        in
          case close of
            NONE => NONE
          | SOME c =>
              let fun go k = if k >= n then NONE
                             else if at k = #"\\" then go (k + 2)
                             else if at k = c then SOME (String.substring (text, j + 1, k - j - 1), k + 1)
                             else if at j = #"(" andalso at k = #"(" then NONE
                             else go (k + 1)
              in go (j + 1) end
        end
      fun endOfLine j = let val j = spaces j in if j >= n then SOME n else if at j = #"\n" then SOME (j + 1) else NONE end
      fun one j =
        case label (spaces j) of
          SOME (l, k) =>
            if at k <> #":" then NONE
            else
              (case destination (spacesNewline (k + 1)) of
                 SOME (d, k2) =>
                   let
                     val t = spacesNewline k2
                     val withTitle =
                       if t > k2 then
                         case title t of
                           SOME (ti, k3) => (case endOfLine k3 of SOME e => SOME (SOME ti, e) | NONE => NONE)
                         | NONE => NONE
                       else NONE
                   in
                     case withTitle of
                       SOME (ti, e) => SOME (l, d, ti, e)
                     | NONE => (case endOfLine k2 of SOME e => SOME (l, d, NONE, e) | NONE => NONE)
                   end
               | NONE => NONE)
        | NONE => NONE
      fun go j =
        case one j of
          SOME (l, d, ti, e) =>
            (if List.exists (fn (k, _) => k = normalise l) (!definitions) then ()
             else definitions := !definitions @ [(normalise l, (unescape d, Option.map unescape ti))];
             go e)
        | NONE => j
    in
      String.extract (text, go 0, NONE)
    end

  fun paragraphText lines = trimRight (String.concatWith "\n" (map trimLeft lines))

  (* blocks, each with whether a blank line came before it *)
  fun blocks (ls : string list) : (raw * bool) list =
    let
      fun go ([], _, acc) = rev acc
        | go (l :: rest, blank, acc) =
            if isBlank l then go (rest, true, acc)
            else if lead l >= 4 then
              let
                fun take (x :: xs, got) = if isBlank x orelse lead x >= 4 then take (xs, dropSpaces (x, 4) :: got) else (rev got, x :: xs)
                  | take ([], got) = (rev got, [])
                val (got, rest) = take (rest, [dropSpaces (l, 4)])
                fun dropBlank xs = rev (let fun d (y :: ys) = if isBlank y then d ys else y :: ys | d [] = [] in d (rev xs) end)
                val got = dropBlank got
              in
                go (rest, false, (RCode {info = "", text = String.concat (map (fn x => x ^ "\n") got)}, blank) :: acc)
              end
            else
              case fence l of
                SOME (f as (_, _, ind, info)) =>
                  let
                    fun take ([], got) = (rev got, [])
                      | take (x :: xs, got) = if closesFence (f, x) then (rev got, xs) else take (xs, dropSpaces (x, ind) :: got)
                    val (got, rest) = take (rest, [])
                    val info = unescape info
                  in
                    go (rest, false, (RCode {info = info, text = String.concat (map (fn x => x ^ "\n") got)}, blank) :: acc)
                  end
              | NONE =>
              case atx l of
                SOME (n, t) => go (rest, false, (RHeading (n, t), blank) :: acc)
              | NONE =>
              if thematic l then go (rest, false, (RRule, blank) :: acc)
              else if quoteStart l then
                let
                  fun take ([], inner) = (rev inner, [])
                    | take (x :: xs, inner) =
                        if quoteStart x then take (xs, quoteRest x :: inner)
                        else if not (isBlank x) andalso not (interrupts x) andalso endsInParagraph (rev inner)
                        then take (xs, lazy x :: inner)
                        else (rev inner, x :: xs)
                  val (inner, rest) = take (rest, [quoteRest l])
                in
                  go (rest, false, (RQuote (map #1 (blocks inner)), blank) :: acc)
                end
              else
                case listStart l of
                  SOME first => list (first, rest, blank, acc)
                | NONE =>
                case htmlStart l of
                  SOME kind =>
                    let
                      fun take ([], got) = (rev got, [])
                        | take (x :: xs, got) =
                            if kind >= 6 then (if isBlank x then (rev got, x :: xs) else take (xs, x :: got))
                            else if htmlEnds (kind, x) then (rev (x :: got), xs)
                            else take (xs, x :: got)
                      val (got, rest) = if kind < 6 andalso htmlEnds (kind, l) then ([l], rest) else take (rest, [l])
                    in
                      go (rest, false, (RHtml (String.concatWith "\n" got), blank) :: acc)
                    end
                | NONE =>
                case (rest, delimiterRow (case rest of x :: _ => x | [] => "")) of
                  (_ :: more, SOME align) =>
                    if CharVector.exists (fn c => c = #"|") l andalso List.length (cells l) = List.length align then
                      let
                        fun take (x :: xs, got) =
                              if isBlank x orelse interrupts x then (rev got, x :: xs) else take (xs, cells x :: got)
                          | take ([], got) = (rev got, [])
                        val (rows, rest) = take (more, [])
                        fun fit r = List.take (r @ List.tabulate (List.length align, fn _ => ""), List.length align)
                      in
                        go (rest, false, (RTable {align = align, header = cells l, rows = map fit rows}, blank) :: acc)
                      end
                    else paragraph (l, rest, blank, acc)
                | _ => paragraph (l, rest, blank, acc)

      and paragraph (l, rest, blank, acc) =
        let
          fun take ([], got) = (rev got, [], NONE)
            | take (x :: xs, got) =
                if isBlank x then (rev got, x :: xs, NONE)
                else case setext x of
                       SOME k => (rev got, xs, SOME k)
                     | NONE => if interrupts x then (rev got, x :: xs, NONE) else take (xs, x :: got)
          val (got, rest', level) = take (rest, [l])
          val text = takeDefinitions (paragraphText got)
        in
          case level of
            SOME k =>
              if text = "" then
                (* only definitions: the underline is a line of its own *)
                go (List.drop (rest, List.length got - 1), false, acc)
              else go (rest', false, (RHeading (k, text), blank) :: acc)
          | NONE => if text = "" then go (rest', false, (RNothing, blank) :: acc)
                    else go (rest', false, (RPara text, blank) :: acc)
        end

      and list (first : {marker : marker, indent : int, rest : string, empty : bool}, rest, blank, acc) =
        let
          (* one item: its lines, the lines after it, and the blank lines
             at its end *)
          fun item ({indent, rest = firstLine, empty, ...} : {marker : marker, indent : int, rest : string, empty : bool}, ls) =
            let
              fun take ([], got) = (rev got, [])
                | take (x :: xs, got) =
                    if isBlank x then
                      (if empty andalso null got then ([], x :: xs) else take (xs, "" :: got))
                    else if lead x >= indent then take (xs, dropSpaces (x, indent) :: got)
                    else if not (null got) andalso not (isBlank (hd got)) andalso endsInParagraph (rev (if empty then got else got))
                            andalso not (interrupts x) andalso not (isSome (listStart x))
                    then take (xs, lazy x :: got)
                    else (rev got, x :: xs)
              val (got, after) = take (ls, if empty then [] else [firstLine])
              fun trailing xs = let fun t (y :: ys, k) = if isBlank y then t (ys, k + 1) else (rev (y :: ys), k)
                                      | t ([], k) = ([], k)
                                in t (rev xs, 0) end
              val (got, blanks) = trailing got
            in
              (got, after, blanks)
            end
          fun items (start, ls, acc, gaps) =
            let
              val (got, after, blanks) = item (start, ls)
              val acc = got :: acc
              fun skip (x :: xs, k) = if isBlank x then skip (xs, k + 1) else (x :: xs, k)
                | skip ([], k) = ([], k)
              val (after', more) = skip (after, 0)
              val back = List.tabulate (blanks, fn _ => "") @ after
            in
              case after' of
                x :: _ =>
                  (case (thematic x, listStart x) of
                     (false, SOME next) =>
                       if sameKind (#marker next, #marker start) then
                         items (next, tl after', acc, gaps orelse blanks + more > 0)
                       else (rev acc, back, gaps)
                   | _ => (rev acc, back, gaps))
              | [] => (rev acc, back, gaps)
            end
          val (lines, after, gaps) = items (first, rest, [], false)
          val parsed = map blocks lines
          val inner = List.exists (fn bs => List.exists (fn (_, b) => b) (case bs of [] => [] | _ :: more => more)) parsed
          val (ordered, start) = case #marker first of Ordered (_, n) => (true, n) | Bullet _ => (false, 1)
        in
          go (after, false, (RList {ordered = ordered, start = start, tight = not (gaps orelse inner),
                                    items = map (map #1) parsed}, blank) :: acc)
        end
    in
      go (ls, false, [])
    end

  (* ------------------------------------------------------------ inlines *)

  datatype cell =
      Lit of inline
    | Delim of {ch : char, n : int ref, orig : int, opens : bool, closes : bool}
    | Bracket of {image : bool, start : int, active : bool ref}

  (* the characters around a position, for the flanking of delimiters *)
  fun charBefore (s, i) =
    if i <= 0 then NONE
    else
      let fun back j = if j > 0 andalso Char.ord (String.sub (s, j)) >= 0x80 andalso Char.ord (String.sub (s, j)) < 0xC0
                       then back (j - 1) else j
          val j = back (i - 1)
      in SOME (#1 (Utf8.next (s, j))) end
  fun charAt (s, i) = if i >= size s then NONE else SOME (#1 (Utf8.next (s, i)))

  fun whiteCode c = c = 0x20 orelse c = 0x09 orelse c = 0x0A orelse c = 0x0C orelse c = 0x0D orelse c = 0xA0
                    orelse c = 0x1680 orelse (c >= 0x2000 andalso c <= 0x200A) orelse c = 0x202F orelse c = 0x205F
                    orelse c = 0x3000
  fun punctCode c =
    (c < 128 andalso Char.isPunct (Char.chr c))
    orelse (c >= 0xA1 andalso c <= 0xBF) orelse c = 0xD7 orelse c = 0xF7
    orelse (c >= 0x2010 andalso c <= 0x2027) orelse (c >= 0x2030 andalso c <= 0x205E)
    orelse (c >= 0x20A0 andalso c <= 0x20C0) orelse (c >= 0x2190 andalso c <= 0x23FF)
    orelse (c >= 0x3001 andalso c <= 0x3003) orelse (c >= 0x3008 andalso c <= 0x3011)
    orelse (c >= 0xFF01 andalso c <= 0xFF0F)

  fun isWhiteAt NONE = true
    | isWhiteAt (SOME c) = whiteCode c
  fun isPunctAt NONE = false
    | isPunctAt (SOME c) = punctCode c

  fun inlines (s : string) : inline list =
    let
      val n = size s
      val cellsArr = ref (Array.array (16, NONE : cell option))
      val used = ref 0
      fun add c =
        (if !used = Array.length (!cellsArr) then
           let val a = Array.array (2 * !used, NONE)
           in Array.copy {src = !cellsArr, dst = a, di = 0}; cellsArr := a end
         else ();
         Array.update (!cellsArr, !used, SOME c);
         used := !used + 1)
      fun get i = Array.sub (!cellsArr, i)
      fun set (i, c) = Array.update (!cellsArr, i, c)
      val brackets : int list ref = ref []
      val buf = ref [] : string list ref
      fun flush () = case !buf of [] => () | b => (add (Lit (Text (String.concat (rev b)))); buf := [])
      fun emit t = buf := t :: !buf

      fun delimText ({ch, n, ...} : {ch : char, n : int ref, orig : int, opens : bool, closes : bool}) =
        CharVector.tabulate (!n, fn _ => ch)

      (* the inlines of the cells from i to j, the delimiters left as text *)
      fun collect (i, j) =
        let
          fun go (k, acc) =
            if k > j then rev acc
            else
              case get k of
                NONE => go (k + 1, acc)
              | SOME (Lit x) => go (k + 1, x :: acc)
              | SOME (Delim d) => go (k + 1, Text (delimText d) :: acc)
              | SOME (Bracket {image, ...}) => go (k + 1, Text (if image then "![" else "[") :: acc)
        in
          go (i, [])
        end
      fun clear (i, j) = if i > j then () else (set (i, NONE); clear (i + 1, j))

      fun processEmphasis bottom =
        let
          val openersBottom = Array.array (12, bottom)
          fun key (ch, orig, opens) = (if ch = #"*" then 0 else 6) + (orig mod 3) * 2 + (if opens then 1 else 0)
          fun loop i =
            if i >= !used then ()
            else
              case get i of
                SOME (Delim (d as {ch, n = cn, orig, opens, closes})) =>
                  if not closes orelse !cn = 0 then loop (i + 1)
                  else
                    let
                      val k = key (ch, orig, opens)
                      fun find j =
                        if j <= Array.sub (openersBottom, k) orelse j <= bottom then NONE
                        else
                          case get j of
                            SOME (Delim (opener as {ch = och, n = on, orig = oorig, opens = oopens, closes = ocloses})) =>
                              if och = ch andalso oopens andalso !on > 0
                                 andalso not ((ocloses orelse opens) andalso (oorig + orig) mod 3 = 0
                                              andalso not (oorig mod 3 = 0 andalso orig mod 3 = 0))
                              then SOME (j, opener) else find (j - 1)
                          | _ => find (j - 1)
                    in
                      case find (i - 1) of
                        SOME (j, opener) =>
                          let
                            val on = #n opener
                            val use = if !on >= 2 andalso !cn >= 2 then 2 else 1
                            val () = on := !on - use
                            val () = cn := !cn - use
                            val content = collect (j + 1, i - 1)
                            val node = if use = 2 then Strong content else Emphasis content
                            fun firstSlot k = if k >= i then NONE else case get k of NONE => firstSlot (k + 1) | SOME _ => SOME k
                            val slot = firstSlot (j + 1)
                            val () = clear (j + 1, i - 1)
                          in
                            (case slot of
                               SOME k => set (k, SOME (Lit node))
                             | NONE => ());
                            (if !on = 0 then set (j, NONE) else ());
                            if !cn = 0 then (set (i, NONE); loop (i + 1)) else loop i
                          end
                      | NONE =>
                          (Array.update (openersBottom, k, i - 1);
                           (if not opens then set (i, SOME (Lit (Text (delimText d)))) else ());
                           loop (i + 1))
                    end
              | _ => loop (i + 1)
        in
          loop (bottom + 1);
          let fun lit i = if i >= !used then ()
                          else ((case get i of SOME (Delim d) => set (i, SOME (Lit (Text (delimText d)))) | _ => ());
                                lit (i + 1))
          in lit (bottom + 1) end
        end

      fun at j = if j < n then String.sub (s, j) else #"\000"
      fun spaces j = if j < n andalso isWhite (at j) then spaces (j + 1) else j
      (* whitespace with at most one newline *)
      fun gap j =
        let
          val k = let fun go m = if m < n andalso isSpaceTab (at m) then go (m + 1) else m in go j end
        in
          if at k = #"\n" then let fun go m = if m < n andalso isSpaceTab (at m) then go (m + 1) else m in go (k + 1) end else k
        end

      (* an inline link's destination and title after "(" at j: the
         destination, the title and where ")" ends *)
      fun inlineLink j =
        let
          val j = gap j
          val dest =
            if at j = #"<" then
              let fun go k = if k >= n orelse at k = #"\n" orelse at k = #"<" then NONE
                             else if at k = #"\\" andalso k + 1 < n then go (k + 2)
                             else if at k = #">" then SOME (String.substring (s, j + 1, k - j - 1), k + 1)
                             else go (k + 1)
              in go (j + 1) end
            else
              let
                fun go (k, depth) =
                  if k >= n orelse Char.ord (at k) <= 32 then (k, depth)
                  else case at k of
                         #"\\" => if k + 1 < n andalso Char.isPunct (at (k + 1)) then go (k + 2, depth) else go (k + 1, depth)
                       | #"(" => go (k + 1, depth + 1)
                       | #")" => if depth = 0 then (k, depth) else go (k + 1, depth - 1)
                       | _ => go (k + 1, depth)
                val (k, depth) = go (j, 0)
              in
                if depth <> 0 then NONE else SOME (String.substring (s, j, k - j), k)
              end
        in
          case dest of
            NONE => NONE
          | SOME (d, k) =>
              let
                val t = gap k
                val title =
                  if t > k then
                    case at t of
                      c =>
                        if not (Char.contains "\"'(" c) then NONE else
                        let
                          val close = if c = #"(" then #")" else c
                          fun go m = if m >= n then NONE
                                     else if at m = #"\\" then go (m + 2)
                                     else if at m = close then SOME (String.substring (s, t + 1, m - t - 1), m + 1)
                                     else if c = #"(" andalso at m = #"(" then NONE
                                     else go (m + 1)
                        in go (t + 1) end
                  else NONE
                val e = gap (case title of SOME (_, m) => m | NONE => k)
              in
                if at e = #")" then SOME (unescape d, Option.map (unescape o #1) title, e + 1) else NONE
              end
        end

      (* a link label at j ("[" there): its text and where it ends *)
      fun linkLabel j =
        if at j <> #"[" then NONE
        else
          let
            fun go k =
              if k >= n orelse k - j > 1000 then NONE
              else case at k of
                     #"\\" => go (k + 2)
                   | #"[" => NONE
                   | #"]" => SOME (String.substring (s, j + 1, k - j - 1), k + 1)
                   | _ => go (k + 1)
          in
            go (j + 1)
          end

      fun lookup label = Option.map #2 (List.find (fn (k, _) => k = normalise label) (!definitions))

      fun closeBracket i =
        case !brackets of
          [] => (emit "]"; i + 1)
        | b :: rest =>
            case get b of
              SOME (Bracket {image, start, active}) =>
                if not (!active) then (brackets := rest; set (b, SOME (Lit (Text (if image then "![" else "[")))); emit "]"; i + 1)
                else
                  let
                    val textSrc = String.substring (s, start, i - start)
                    val target =
                      case (if at (i + 1) = #"(" then inlineLink (i + 2) else NONE) of
                        SOME (d, t, e) => SOME (d, t, e)
                      | NONE =>
                          case linkLabel (i + 1) of
                            SOME (l, e) =>
                              if trim l = "" then
                                (case lookup textSrc of SOME (d, t) => SOME (d, t, e) | NONE => NONE)
                              else (case lookup l of SOME (d, t) => SOME (d, t, e) | NONE => NONE)
                          | NONE =>
                              if at (i + 1) = #"[" andalso at (i + 2) = #"]" then
                                (case lookup textSrc of SOME (d, t) => SOME (d, t, i + 3) | NONE => NONE)
                              else (case lookup textSrc of SOME (d, t) => SOME (d, t, i + 1) | NONE => NONE)
                  in
                    case target of
                      SOME (d, t, e) =>
                        let
                          val () = flush ()
                          val () = processEmphasis b
                          val content = collect (b + 1, !used - 1)
                          val () = clear (b + 1, !used - 1)
                          val node = if image then Image {source = d, title = t, alt = content}
                                     else Link {target = d, title = t, text = content}
                        in
                          set (b, SOME (Lit node));
                          brackets := rest;
                          (if image then ()
                           else List.app (fn k => case get k of SOME (Bracket {image = false, active, ...}) => active := false | _ => ())
                                         rest);
                          e
                        end
                    | NONE =>
                        (brackets := rest; set (b, SOME (Lit (Text (if image then "![" else "[")))); emit "]"; i + 1)
                  end
            | _ => (brackets := rest; emit "]"; i + 1)

      fun codeSpan i =
        let
          val k = count (s, i, #"`")
          fun find j =
            if j >= n then NONE
            else if at j = #"`" then
              let val m = count (s, j, #"`") in if m = k then SOME j else find (j + m) end
            else find (j + 1)
        in
          case find (i + k) of
            SOME j =>
              let
                val raw = String.map (fn #"\n" => #" " | c => c) (String.substring (s, i + k, j - i - k))
                val raw = if size raw >= 2 andalso String.sub (raw, 0) = #" " andalso String.sub (raw, size raw - 1) = #" "
                             andalso not (CharVector.all (fn c => c = #" ") raw)
                          then String.substring (raw, 1, size raw - 2) else raw
              in
                flush (); add (Lit (Code raw)); j + k
              end
          | NONE => (emit (String.substring (s, i, k)); i + k)
        end

      fun autolink i =
        let
          fun scheme j = let fun go k = if k < n andalso (Char.isAlphaNum (at k) orelse Char.contains "+.-" (at k)) then go (k + 1) else k
                         in if Char.isAlpha (at j) then go (j + 1) else j end
          val e = scheme (i + 1)
        in
          if e - (i + 1) >= 2 andalso e - (i + 1) <= 32 andalso at e = #":" then
            let fun go k = if k >= n then NONE
                           else if at k = #">" then SOME k
                           else if Char.ord (at k) <= 32 orelse at k = #"<" then NONE
                           else go (k + 1)
            in
              case go (e + 1) of
                SOME k => let val url = String.substring (s, i + 1, k - i - 1)
                          in SOME (Link {target = url, title = NONE, text = [Text url]}, k + 1) end
              | NONE => NONE
            end
          else
            (* an e-mail address *)
            let
              fun local' k = if k < n andalso (Char.isAlphaNum (at k) orelse Char.contains ".!#$%&'*+/=?^_`{|}~-" (at k)) then local' (k + 1) else k
              val a = local' (i + 1)
              fun label k = let fun go m = if m < n andalso (Char.isAlphaNum (at m) orelse at m = #"-") then go (m + 1) else m
                            in if Char.isAlphaNum (at k) then SOME (go (k + 1)) else NONE end
              fun domain k = case label k of
                               SOME m => if at m = #"." then domain (m + 1) else SOME m
                             | NONE => NONE
            in
              if a > i + 1 andalso at a = #"@" then
                case domain (a + 1) of
                  SOME m => if at m = #">" andalso m > a + 1 then
                              let val addr = String.substring (s, i + 1, m - i - 1)
                              in SOME (Link {target = "mailto:" ^ addr, title = NONE, text = [Text addr]}, m + 1) end
                            else NONE
                | NONE => NONE
              else NONE
            end
        end

      fun rawHtml i =
        let
          fun until (t, j) = let fun go k = if k + size t > n then NONE else if startsWith (s, k, t) then SOME (k + size t) else go (k + 1)
                             in go j end
          val e =
            if startsWith (s, i, "<!-->") then SOME (i + 5)
            else if startsWith (s, i, "<!--->") then SOME (i + 6)
            else if startsWith (s, i, "<!--") then until ("-->", i + 4)
            else if startsWith (s, i, "<?") then until ("?>", i + 2)
            else if startsWith (s, i, "<![CDATA[") then until ("]]>", i + 9)
            else if startsWith (s, i, "<!") andalso Char.isAlpha (at (i + 2)) then until (">", i + 2)
            else scanTag (s, i)
        in
          Option.map (fn e => (Html (String.substring (s, i, e - i)), e)) e
        end

      fun delimiter i =
        let
          val c = at i
          val k = count (s, i, c)
          val prev = charBefore (s, i)
          val next = charAt (s, i + k)
          val left = not (isWhiteAt next) andalso (not (isPunctAt next) orelse isWhiteAt prev orelse isPunctAt prev)
          val right = not (isWhiteAt prev) andalso (not (isPunctAt prev) orelse isWhiteAt next orelse isPunctAt next)
          val (opens, closes) =
            if c = #"*" then (left, right)
            else (left andalso (not right orelse isPunctAt prev), right andalso (not left orelse isPunctAt next))
        in
          flush ();
          add (Delim {ch = c, n = ref k, orig = k, opens = opens, closes = closes});
          i + k
        end

      fun lineBreak i =
        let
          val b = String.concat (rev (!buf))
          fun spacesAtEnd k = if k > 0 andalso String.sub (b, k - 1) = #" " then spacesAtEnd (k - 1) else k
          val k = spacesAtEnd (size b)
          val hard = size b - k >= 2
        in
          buf := [String.substring (b, 0, k)];
          flush ();
          add (Lit (if hard then HardBreak else SoftBreak));
          let fun skip j = if j < n andalso isSpaceTab (at j) then skip (j + 1) else j in skip (i + 1) end
        end

      fun scan i =
        if i >= n then ()
        else
          case at i of
            #"\\" =>
              if at (i + 1) = #"\n" then (flush (); add (Lit HardBreak);
                                          let fun skip j = if j < n andalso isSpaceTab (at j) then skip (j + 1) else j in scan (skip (i + 2)) end)
              else if i + 1 < n andalso Char.isPunct (at (i + 1)) then (emit (String.str (at (i + 1))); scan (i + 2))
              else (emit "\\"; scan (i + 1))
          | #"`" => scan (codeSpan i)
          | #"&" => (case entity (s, i) of SOME (v, j) => (emit v; scan j) | NONE => (emit "&"; scan (i + 1)))
          | #"<" =>
              (case autolink i of
                 SOME (l, j) => (flush (); add (Lit l); scan j)
               | NONE =>
                   case rawHtml i of
                     SOME (h, j) => (flush (); add (Lit h); scan j)
                   | NONE => (emit "<"; scan (i + 1)))
          | #"*" => scan (delimiter i)
          | #"_" => scan (delimiter i)
          | #"[" => (flush (); brackets := !used :: !brackets; add (Bracket {image = false, start = i + 1, active = ref true}); scan (i + 1))
          | #"!" =>
              if at (i + 1) = #"[" then
                (flush (); brackets := !used :: !brackets; add (Bracket {image = true, start = i + 2, active = ref true}); scan (i + 2))
              else (emit "!"; scan (i + 1))
          | #"]" => (flush (); scan (closeBracket i))
          | #"\n" => scan (lineBreak i)
          | c =>
              let fun plain j = if j < n andalso not (Char.contains "\\`&<*_[!]\n" (at j)) then plain (j + 1) else j
                  val j = plain (i + 1)
              in emit (String.substring (s, i, j - i)); scan j end
      val () = scan 0
      val () = flush ()
      val () = processEmphasis ~1
      fun merge (Text a :: Text b :: rest) = merge (Text (a ^ b) :: rest)
        | merge (x :: rest) = x :: merge rest
        | merge [] = []
      fun deep (Emphasis xs) = Emphasis (merge (map deep xs))
        | deep (Strong xs) = Strong (merge (map deep xs))
        | deep (Link {target, title, text}) = Link {target = target, title = title, text = merge (map deep text)}
        | deep (Image {source, title, alt}) = Image {source = source, title = title, alt = merge (map deep alt)}
        | deep x = x
    in
      merge (map deep (collect (0, !used - 1)))
    end

  fun cook (r : raw) : block option =
    case r of
      RHeading (k, t) => SOME (Heading (k, inlines t))
    | RPara t => SOME (Paragraph (inlines t))
    | RCode c => SOME (CodeBlock c)
    | RHtml h => SOME (HtmlBlock h)
    | RQuote bs => SOME (Quote (List.mapPartial cook bs))
    | RList {ordered, start, tight, items} =>
        SOME (List {ordered = ordered, start = start, tight = tight, items = map (List.mapPartial cook) items})
    | RTable {align, header, rows} => SOME (Table {align = align, header = map inlines header, rows = map (map inlines) rows})
    | RRule => SOME Rule
    | RNothing => NONE

  fun parse text =
    let
      val () = definitions := []
      val raws = map #1 (blocks (linesOf text))
    in
      List.mapPartial cook raws before definitions := []
    end

  (* ------------------------------------------------------------ HTML *)

  fun escape s =
    String.translate (fn #"&" => "&amp;" | #"<" => "&lt;" | #">" => "&gt;" | #"\"" => "&quot;" | c => String.str c) s

  (* a URL as cmark writes it: what is not safe in an href percent-encoded *)
  fun escapeHref s =
    String.translate (fn c =>
      if Char.isAlphaNum c orelse Char.contains ";/?:@=+$,-_.!~*'()#%" c then String.str c
      else if c = #"&" then "&amp;"
      else "%" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))) s

  fun plainText xs =
    String.concat (map (fn Text t => t | Code c => c | Emphasis ys => plainText ys | Strong ys => plainText ys
                         | Link {text, ...} => plainText text | Image {alt, ...} => plainText alt
                         | Html h => h | SoftBreak => "\n" | HardBreak => "\n") xs)

  fun inlineHtml xs =
    String.concat (map (fn x =>
      case x of
        Text t => escape t
      | Code c => "<code>" ^ escape c ^ "</code>"
      | Emphasis ys => "<em>" ^ inlineHtml ys ^ "</em>"
      | Strong ys => "<strong>" ^ inlineHtml ys ^ "</strong>"
      | Link {target, title, text} =>
          "<a href=\"" ^ escapeHref target ^ "\"" ^ (case title of SOME t => " title=\"" ^ escape t ^ "\"" | NONE => "")
          ^ ">" ^ inlineHtml text ^ "</a>"
      | Image {source, title, alt} =>
          "<img src=\"" ^ escapeHref source ^ "\" alt=\"" ^ escape (plainText alt) ^ "\""
          ^ (case title of SOME t => " title=\"" ^ escape t ^ "\"" | NONE => "") ^ " />"
      | Html h => h
      | SoftBreak => "\n"
      | HardBreak => "<br />\n") xs)

  fun toHtml bs =
    let
      val out = ref [] : string list ref
      val lastNewline = ref true
      fun put "" = ()
        | put s = (out := s :: !out; lastNewline := String.sub (s, size s - 1) = #"\n")
      fun cr () = if !lastNewline then () else put "\n"
      fun block tight b =
        case b of
          Heading (k, xs) => (cr (); put ("<h" ^ Int.toString k ^ ">" ^ inlineHtml xs ^ "</h" ^ Int.toString k ^ ">\n"))
        | Paragraph xs => if tight then put (inlineHtml xs) else (cr (); put ("<p>" ^ inlineHtml xs ^ "</p>\n"))
        | CodeBlock {info, text} =>
            let val lang = case String.tokens isWhite info of w :: _ => " class=\"language-" ^ escape w ^ "\"" | [] => ""
            in cr (); put ("<pre><code" ^ lang ^ ">" ^ escape text ^ "</code></pre>\n") end
        | HtmlBlock h => (cr (); put (h ^ "\n"))
        | Quote xs => (cr (); put "<blockquote>\n"; List.app (block false) xs; cr (); put "</blockquote>\n")
        | List {ordered, start, tight = t, items} =>
            (cr ();
             put (if ordered then (if start = 1 then "<ol>\n" else "<ol start=\"" ^ Int.toString start ^ "\">\n") else "<ul>\n");
             List.app (fn xs => (cr (); put "<li>"; List.app (block t) xs; put "</li>\n")) items;
             put (if ordered then "</ol>\n" else "</ul>\n"))
        | Table {align, header, rows} =>
            let
              fun attr Default = "" | attr Left = " align=\"left\"" | attr Center = " align=\"center\"" | attr Right = " align=\"right\""
              fun row (tag, cs) = "<tr>\n" ^ String.concat (ListPair.map (fn (a, c) => "<" ^ tag ^ attr a ^ ">" ^ inlineHtml c ^ "</" ^ tag ^ ">\n") (align, cs)) ^ "</tr>\n"
            in
              cr ();
              put ("<table>\n<thead>\n" ^ row ("th", header) ^ "</thead>\n"
                   ^ (if null rows then "" else "<tbody>\n" ^ String.concat (map (fn r => row ("td", r)) rows) ^ "</tbody>\n")
                   ^ "</table>\n")
            end
        | Rule => (cr (); put "<hr />\n")
    in
      List.app (block false) bs;
      String.concat (rev (!out))
    end

  (* ------------------------------------------------------------ documents *)

  structure P = Pretty

  fun words t = String.tokens isWhite t

  (* inlines as a document whose breaks fill the line *)
  fun inlineDoc xs =
    let
      fun textDoc t =
        let
          val ws = words t
          val lead = size t > 0 andalso isWhite (String.sub (t, 0))
          val trail = size t > 0 andalso isWhite (String.sub (t, size t - 1))
          fun join [] = []
            | join [w] = [P.text w]
            | join (w :: rest) = P.text w :: P.group P.line :: join rest
        in
          (if lead then [P.group P.line] else []) @ join ws @ (if trail andalso not (null ws) then [P.group P.line] else [])
        end
      fun one x =
        case x of
          Text t => textDoc t
        | Code c => [P.annotate (Mono, P.text c)]
        | Emphasis ys => [P.annotate (Italic, P.concat (List.concat (map one ys)))]
        | Strong ys => [P.annotate (Bold, P.concat (List.concat (map one ys)))]
        | Link {target, text, ...} => [P.annotate (Anchor target, P.concat (List.concat (map one text)))]
        | Image {alt, ...} => List.concat (map one alt)
        | Html _ => []
        | SoftBreak => [P.group P.line]
        | HardBreak => [P.hardline]
    in
      P.concat (List.concat (map one xs))
    end

  fun width t = DisplayWidth.columns t

  fun blockDoc b =
    case b of
      Heading (k, xs) => P.annotate (Head k, inlineDoc xs)
    | Paragraph xs => inlineDoc xs
    | CodeBlock {text, ...} =>
        let val ls = String.fields (fn c => c = #"\n") (trimRight text)
        in P.annotate (Mono, P.concat (List.concat (List.tabulate (List.length ls, fn i =>
             (if i > 0 then [P.hardline] else []) @ [P.text (List.nth (ls, i))])))) end
    | HtmlBlock h =>
        (* what the HTML says, without its tags *)
        let
          fun strip (i, acc) =
            if i >= size h then String.implode (rev acc)
            else if String.sub (h, i) = #"<" then
              let fun close j = if j >= size h then j else if String.sub (h, j) = #">" then j + 1 else close (j + 1)
              in strip (close i, acc) end
            else strip (i + 1, String.sub (h, i) :: acc)
          val text = unescape (strip (0, []))
          val ls = List.filter (fn l => not (isBlank l)) (String.fields (fn c => c = #"\n") text)
        in
          P.annotate (Mono, P.concat (List.concat (List.tabulate (List.length ls, fn i =>
            (if i > 0 then [P.hardline] else []) @ [P.text (List.nth (ls, i))]))))
        end
    | Quote xs => P.annotate (Quoted, P.concat [P.text "| ", P.nest 2 (blocksDoc xs)])
    | List {ordered, start, tight, items} =>
        let
          fun marker i = if ordered then Int.toString (start + i) ^ ". " else "- "
          val w = foldl (fn (i, m) => Int.max (m, size (marker i))) 0 (List.tabulate (List.length items, fn i => i))
          fun item (i, xs) =
            P.concat [P.annotate (Marker, P.text (StringCvt.padRight #" " w (marker i))),
                      P.nest w (sep (if tight then [P.hardline] else [P.hardline, P.hardline]) (map blockDoc xs))]
        in
          sep (if tight then [P.hardline] else [P.hardline, P.hardline])
              (List.tabulate (List.length items, fn i => item (i, List.nth (items, i))))
        end
    | Table {header, rows, ...} =>
        let
          val all = header :: rows
          val texts = map (map (fn c => trim (plainText c))) all
          val columns = List.length header
          val widths = List.tabulate (columns, fn k => foldl (fn (r, m) => Int.max (m, width (List.nth (r, k)) handle Subscript => m)) 0 texts)
          fun cell (t, w) = t ^ CharVector.tabulate (Int.max (0, w - width t), fn _ => #" ")
          fun row r = P.text (trimRight (String.concatWith "  " (ListPair.map cell (r, widths))))
          val rule = P.annotate (Ruler, P.text (String.concatWith "  " (map (fn w => CharVector.tabulate (w, fn _ => #"-")) widths)))
        in
          sep [P.hardline] (P.annotate (Bold, row (hd texts)) :: rule :: map row (tl texts))
        end
    | Rule => P.annotate (Ruler, P.text "----")

  and sep _ [] = P.empty
    | sep between (d :: ds) = P.concat (d :: List.concat (map (fn x => between @ [x]) ds))

  and blocksDoc bs = sep [P.hardline, P.hardline] (map blockDoc bs)

  fun toDoc bs = blocksDoc bs

  fun toText w bs =
    String.concatWith "\n" (map trimRight (String.fields (fn c => c = #"\n") (P.render w (toDoc bs))))
end

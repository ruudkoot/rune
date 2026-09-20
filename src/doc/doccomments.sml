(* The comments of a file and what each of them documents
   (docs/plans/docgen.md, D2). Attachment is by line:

     before   a comment on lines of its own, directly above an item (no blank
              line between them), documents that item;
     after    a comment that follows an item on the line of the item's last
              token documents that item; a comma or a `|` between them does
              not matter, and of several items that end there it is the
              innermost;
     heading  a comment that starts with `----` is a section heading;
     prose    any other comment on lines of its own that a blank line, another
              comment or `end` follows stands for itself.

   Inside a documented signature a comment that is none of these is an error:
   no comment is dropped silently. An item is anything that can be documented:
   a module binding, a specification, a constructor, a field. *)
structure DocComments =
struct
  structure S = DocSource

  type comment = {start : int, stop : int, text : string}

  (* What the comments of a file turned out to be. docs: the comments of the
     item that starts at the key, those before it first. standalone: headings
     and prose, in source order. *)
  type table = {docs : comment list IntMap.map, standalone : comment list ref}

  val empty : table = {docs = IntMap.empty, standalone = ref []}

  (* ---- the text of a comment ---- *)
  fun trimLeft (s : string) : string =
    let fun go k = if k < String.size s andalso Char.isSpace (String.sub (s, k)) then go (k + 1) else k
    in String.extract (s, go 0, NONE) end

  (* The text between the delimiters, with the lines after the first moved
     left to the margin of the text, which is three columns to the right of
     the comment's `(`; blank lines at both ends go. *)
  fun textOf (src : S.t, start : int, stop : int) : string =
    let
      val margin = S.columnOf (src, start) + 3
      fun dedent l =
        let fun go k = if k < margin andalso k < String.size l andalso String.sub (l, k) = #" " then go (k + 1) else k
        in String.extract (l, go 0, NONE) end
      fun dropBlank ls = case ls of l :: rest => if l = "" then dropBlank rest else ls | [] => []
    in
      case String.fields (fn c => c = #"\n") (S.substring (src, start + 2, stop - 2)) of
        [] => ""
      | first :: rest =>
        let val ls = trimLeft (S.trimRight first) :: List.map (fn l => S.trimRight (dedent l)) rest
        in String.concatWith "\n" (List.rev (dropBlank (List.rev (dropBlank ls)))) end
    end

  fun isHeading ({text, ...} : comment) : bool = String.isPrefix "----" text

  (* The title of a heading: what stands between its dashes. *)
  fun headingTitle ({text, ...} : comment) : string =
    let
      val isDash = fn c => c = #"-" orelse Char.isSpace c
      val cs = String.explode text
      fun dropl l = case l of c :: rest => if isDash c then dropl rest else l | [] => []
    in
      String.implode (List.rev (dropl (List.rev (dropl cs))))
    end

  (* ---- lines ---- *)
  fun newlines (src : S.t, a : int, b : int) : int =
    let
      val s = S.text src
      fun go (i, n) = if i >= b then n else go (i + 1, if String.sub (s, i) = #"\n" then n + 1 else n)
    in go (a, 0) end

  (* No token stands before position pos on its line. *)
  fun startsLine (src : S.t, pos : int) : bool =
    let
      val s = S.text src
      fun go i = i < 0 orelse String.sub (s, i) = #"\n" orelse (Char.isSpace (String.sub (s, i)) andalso go (i - 1))
    in go (pos - 1) end

  (* A token that may stand between a comment and the item it documents. *)
  fun isPrefix (t : Token.token) : bool =
    case t of
      Token.VAL => true | Token.TYPE => true | Token.EQTYPE => true | Token.DATATYPE => true
    | Token.EXCEPTION => true | Token.STRUCTURE => true | Token.SIGNATURE => true | Token.FUNCTOR => true
    | Token.INCLUDE => true | Token.SHARING => true | Token.AND => true | Token.BAR => true
    | Token.OP => true | Token.COMMA => true
    | Token.EQUALS => true      (* a comment above `= A`, the first constructor of a datatype *)
    | _ => false

  (* items: the (start, stop) of everything that can be documented.
     regions: the (start, stop) of the signature bodies, from `sig` to after
     `end`; an unattached comment in one of them is an error. *)
  fun attach (src : S.t, items : (int * int) list, regions : (int * int) list) : table =
    let
      val n = S.numTokens src
      val starts = List.foldl (fn ((a, b), m) => IntMap.insert (m, a, b)) IntMap.empty items
      (* stop -> the start of the innermost item that ends there *)
      val stops = List.foldl (fn ((a, b), m) =>
                                case IntMap.find (m, b) of
                                  SOME a' => if a > a' then IntMap.insert (m, b, a) else m
                                | NONE => IntMap.insert (m, b, a))
                             IntMap.empty items
      val docs : comment list IntMap.map ref = ref IntMap.empty
      val standalone : comment list ref = ref []
      fun add (key, c) =
        docs := IntMap.insert (!docs, key, (case IntMap.find (!docs, key) of SOME cs => cs @ [c] | NONE => [c]))
      fun inRegion pos = List.exists (fn (a, b) => a < pos andalso pos < b) regions
      fun spanOf ({start, stop, ...} : comment) : Source.span = {file = S.name src, start = start, stop = stop}
      fun lost (c, why) = if inRegion (#start c) then DocDiag.error (spanOf c, why) else ()

      (* The item that begins at token i or after prefix tokens from it. *)
      fun itemFrom i =
        if i >= n then NONE
        else if IntMap.member (starts, S.tokenStart (src, i)) then SOME (S.tokenStart (src, i))
        else if isPrefix (S.token (src, i)) then itemFrom (i + 1)
        else NONE

      (* The item whose last token is token p, or the token before it when p
         is a comma or a bar on the same line. *)
      fun itemEndingAt p =
        if p < 0 then NONE
        else
          case IntMap.find (stops, S.tokenStop (src, p)) of
            SOME a => SOME a
          | NONE =>
            if p > 0 andalso (S.token (src, p) = Token.COMMA orelse S.token (src, p) = Token.BAR)
               andalso S.lineOf (src, S.tokenStart (src, p - 1)) = S.lineOf (src, S.tokenStart (src, p))
            then IntMap.find (stops, S.tokenStop (src, p - 1))
            else NONE

      (* The comments of the gap before token i, first to last. `next` is
         what follows a comment: the start of the next comment or of token i. *)
      fun gap i =
        let
          val cs = S.commentsBefore (src, i)
          fun go [] = ()
            | go ({start, stop} :: rest) =
              let
                val c = {start = start, stop = stop, text = textOf (src, start, stop)}
                val next = case rest of {start = s, ...} :: _ => s | [] => S.tokenStart (src, i)
                val last = List.null rest
                val blankAfter = newlines (src, stop, next) >= 2
              in
                (if isHeading c then
                   (if inRegion start then standalone := c :: !standalone else ())
                 else if not (startsLine (src, start)) then
                   (case itemEndingAt (i - 1) of
                      SOME key => add (key, c)
                    | NONE => lost (c, "this comment follows nothing that can be documented: put it above what it describes"))
                 else if last andalso not blankAfter then
                   (case itemFrom i of
                      SOME key => add (key, c)
                    | NONE =>
                      if i < n andalso S.token (src, i) = Token.END andalso inRegion start then standalone := c :: !standalone
                      else lost (c, "this comment stands above nothing that can be documented: a blank line after it makes it a paragraph of its section"))
                 else if blankAfter then
                   (if inRegion start then standalone := c :: !standalone else ())
                 else
                   lost (c, "two comments above one item: join them, or put a blank line between them"));
                go rest
              end
        in go cs end
      fun loop i = if i >= n then () else (gap i; loop (i + 1))
    in
      loop 0;
      {docs = !docs, standalone = ref (List.rev (!standalone))}
    end

  fun docsOf ({docs, ...} : table, start : int) : comment list =
    case IntMap.find (docs, start) of SOME cs => cs | NONE => []

  (* The headings and prose of [a, b) that no inner body has taken yet. *)
  fun takeStandalone ({standalone, ...} : table, a : int, b : int) : comment list =
    let val (mine, others) = List.partition (fn c : comment => a <= #start c andalso #start c < b) (!standalone)
    in standalone := others; mine end
end

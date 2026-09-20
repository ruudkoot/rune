(* The language of doc comments (docs/plans/docgen.md, D3). Plain prose is
   always correct: a comment is paragraphs separated by blank lines; a
   paragraph indented by four or more is code; one whose lines start with "- "
   is a list; text between backquotes is code; a bare URL is a link. Nothing
   else is markup. A paragraph that starts with one of a closed set of
   keywords and a colon is reserved: it says something that can be checked
   (`Raises:`) or that the generator uses (`Implements:`). *)
structure DocText =
struct
  datatype inline =
      Text of string
    | Code of string              (* on one line: a line end in the source is a blank *)
    | Url of string

  datatype block =
      Para of inline list
    | CodeBlock of string
    | Bullets of inline list list
    | Reserved of {keyword : string, modifier : string option, body : inline list}

  (* The reserved paragraphs. The notes are those that record how the library
     reads or departs from its specification (D5). *)
  val notes = ["Reading", "Erratum", "Deviation", "Implementation", "Limitation"]
  val keywords = ["Raises", "Example", "Law", "Complexity", "See also", "Area", "Status", "Implements", "Pinned by"] @ notes
  val statuses = ["required", "optional", "extension"]

  fun isNote k = List.exists (fn n => n = k) notes

  (* ---- inlines ---- *)
  fun oneLine (s : string) : string = String.concatWith " " (String.tokens Char.isSpace s)

  (* Where a URL that begins at i ends: at white space, and before the
     punctuation that ends a sentence or closes a parenthesis around it. *)
  fun urlEnd (s : string, i : int) : int =
    let
      val n = String.size s
      fun go j = if j < n andalso not (Char.isSpace (String.sub (s, j))) then go (j + 1) else j
      fun back j = if j > i andalso Char.contains ".,;:)!?" (String.sub (s, j - 1)) then back (j - 1) else j
    in back (go i) end

  fun startsAt (s : string, i : int, prefix : string) : bool =
    i + String.size prefix <= String.size s andalso String.substring (s, i, String.size prefix) = prefix

  (* The text of a paragraph as inlines; `bad` is told of a backquote that
     has no partner. *)
  fun inlines (bad : string -> unit) (s : string) : inline list =
    let
      val n = String.size s
      fun text (a, b, acc) = if b > a then Text (String.substring (s, a, b - a)) :: acc else acc
      (* from: where the pending text began *)
      fun go (from, i, acc) =
        if i >= n then List.rev (text (from, n, acc))
        else if String.sub (s, i) = #"`" then
          let
            fun close j = if j >= n then NONE else if String.sub (s, j) = #"`" then SOME j else close (j + 1)
          in
            case close (i + 1) of
              SOME j => go (j + 1, j + 1, Code (oneLine (String.substring (s, i + 1, j - i - 1))) :: text (from, i, acc))
            | NONE => (bad "a backquote without a partner: code stands between two backquotes"; List.rev (text (from, n, acc)))
          end
        else if startsAt (s, i, "http://") orelse startsAt (s, i, "https://") then
          let val j = urlEnd (s, i)
          in go (j, j, Url (String.substring (s, i, j - i)) :: text (from, i, acc)) end
        else go (from, i + 1, acc)
    in
      go (0, 0, [])
    end

  (* ---- blocks ---- *)
  fun indentOf (l : string) : int =
    let fun go k = if k < String.size l andalso String.sub (l, k) = #" " then go (k + 1) else k
    in go 0 end

  (* The lines of a comment in paragraphs: runs of lines that are not blank. *)
  fun paragraphs (lines : string list) : string list list =
    let
      fun go ([], cur, acc) = List.rev (if List.null cur then acc else List.rev cur :: acc)
        | go (l :: rest, cur, acc) =
            if List.all Char.isSpace (String.explode l) then go (rest, [], if List.null cur then acc else List.rev cur :: acc)
            else go (rest, l :: cur, acc)
    in go (lines, [], []) end

  (* "Keyword:" or "Keyword (modifier):" at the start of a line, for a
     reserved keyword: the keyword, the modifier and the rest of the line. *)
  fun reservedHead (l : string) : (string * string option * string) option =
    let
      fun try k =
        if not (String.isPrefix k l) then NONE
        else
          let val rest = String.extract (l, String.size k, NONE)
          in
            if String.isPrefix ":" rest then SOME (k, NONE, String.extract (rest, 1, NONE))
            else if String.isPrefix " (" rest then
              (case String.fields (fn c => c = #")") (String.extract (rest, 2, NONE)) of
                 m :: after :: more =>
                   let val after = String.concatWith ")" (after :: more)
                   in if String.isPrefix ":" after then SOME (k, SOME m, String.extract (after, 1, NONE)) else NONE end
               | _ => NONE)
            else NONE
          end
      fun first [] = NONE
        | first (k :: ks) = (case try k of SOME r => SOME r | NONE => first ks)
    in
      first keywords
    end

  fun block (bad : string -> unit) (lines : string list) : block =
    let
      val inl = inlines bad
      val joined = String.concatWith "\n"
    in
      if List.all (fn l => indentOf l >= 4) lines then
        CodeBlock (joined (List.map (fn l => String.extract (l, 4, NONE)) lines))
      else if String.isPrefix "- " (List.hd lines) then
        let
          fun items ([], cur, acc) = List.rev (if List.null cur then acc else joined (List.rev cur) :: acc)
            | items (l :: rest, cur, acc) =
                if String.isPrefix "- " l then
                  items (rest, [String.extract (l, 2, NONE)], if List.null cur then acc else joined (List.rev cur) :: acc)
                else items (rest, String.extract (l, indentOf l, NONE) :: cur, acc)
        in Bullets (List.map inl (items (lines, [], []))) end
      else
        case reservedHead (List.hd lines) of
          SOME (k, m, rest) =>
            Reserved {keyword = k, modifier = m,
                      body = inl (joined (List.filter (fn l => l <> "") (String.extract (rest, indentOf rest, NONE) :: List.tl lines)))}
        | NONE => Para (inl (joined lines))
    end

  (* Code paragraphs that a blank line separates are one block. *)
  fun mergeCode (bs : block list) : block list =
    case bs of
      CodeBlock a :: CodeBlock b :: rest => mergeCode (CodeBlock (a ^ "\n\n" ^ b) :: rest)
    | b :: rest => b :: mergeCode rest
    | [] => []

  fun parse (bad : string -> unit) (text : string) : block list =
    mergeCode (List.map (block bad) (paragraphs (String.fields (fn c => c = #"\n") text)))

  (* ---- what a reserved paragraph must look like ---- *)
  fun firstCode (body : inline list) : string option =
    case body of
      Code c :: _ => SOME c
    | Text t :: rest => if List.all Char.isSpace (String.explode t) then firstCode rest else NONE
    | _ => NONE

  fun plain (body : inline list) : string =
    oneLine (String.concat (List.map (fn Text t => t | Code c => c | Url u => u) body))

  (* The complaint about a reserved paragraph that is not well formed. *)
  fun malformed ({keyword, modifier, body} : {keyword : string, modifier : string option, body : inline list}) : string option =
    let
      val hasCode = List.exists (fn Code _ => true | _ => false) body
    in
      if isSome modifier andalso not (keyword = "Reading" andalso modifier = SOME "the suite differs") then
        SOME ("`" ^ keyword ^ " (" ^ valOf modifier ^ "):` is not known: the one modifier is `Reading (the suite differs):`")
      else if isNote keyword then
        (if isSome (firstCode body) then NONE
         else SOME ("`" ^ keyword ^ ":` begins with the note's id in backquotes, as in `" ^ keyword ^ ": `Char.fromString/unescaped-double-quote`. ...`"))
      else
        case keyword of
          "Raises" => if isSome (firstCode body) then NONE
                      else SOME "`Raises:` begins with the exception in backquotes, then says when"
        | "See also" => if hasCode then NONE else SOME "`See also:` names what to see in backquotes"
        | "Pinned by" => if hasCode then NONE else SOME "`Pinned by:` lists labels of checks in backquotes"
        | "Status" => if List.exists (fn s => s = plain body) statuses then NONE
                      else SOME "`Status:` is one of required, optional and extension"
        | _ => if plain body = "" then SOME ("`" ^ keyword ^ ":` says nothing") else NONE
    end

  (* ---- the text form, for DocIR.dump ---- *)
  fun inlineText (i : inline) : string =
    case i of Text t => t | Code c => "`" ^ c ^ "`" | Url u => "<" ^ u ^ ">"

  fun inlinesText (is : inline list) : string = String.concat (List.map inlineText is)
end

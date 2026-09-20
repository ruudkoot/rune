(* Annotations (docs/plans/docgen.md, D5): what someone other than the
   library's authors has to say about its members, from a file that is made
   elsewhere. The documentation of the Basis Library uses it for what the test
   suite knows about other implementations. A line is

       glob | whom or what it is about | text

   `@title TEXT` names the block that the annotations of a member are shown
   in, `@intro TEXT` says for the page on how to read the documentation what
   they are, and # begins a comment. The glob is that of a test label, `Structure.member/case`,
   with * ? and [...] as the shell has them: the annotation belongs to every
   member that has a check with such a label. Without a suite only the part
   before the slash is compared, with the names of the members. *)
structure DocAnnot =
struct
  type annotation = {glob : string, about : string, text : string, span : Source.span}
  type file = {path : string, title : string, intro : string, annotations : annotation list}

  val defaultTitle = "Annotations"

  fun trim (s : string) : string =
    Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full s)))

  fun load (path : string) : file =
    let
      val text = #text (Source.load path)
      val title = ref defaultTitle
      val intro = ref ""
      (* a line with the offset it begins at, so that a diagnostic names it *)
      fun one (l, (pos, acc)) =
        let
          val t = trim l
          val span = {file = path, start = pos, stop = pos + String.size l}
          val next = pos + String.size l + 1
          fun malformed () = (DocDiag.error (span, "an annotation is `glob | whom it is about | text`"); (next, acc))
        in
          if t = "" orelse String.isPrefix "#" t then (next, acc)
          else if String.isPrefix "@title " t then (title := trim (String.extract (t, 7, NONE)); (next, acc))
          else if String.isPrefix "@intro " t then (intro := trim (String.extract (t, 7, NONE)); (next, acc))
          else
            case String.fields (fn c => c = #"|") t of
              glob :: about :: rest =>
                if List.null rest orelse trim glob = "" then malformed ()
                else
                  (* the text is the rest of the line: it may hold a bar itself *)
                  (next, {glob = trim glob, about = trim about, text = trim (String.concatWith "|" rest), span = span} :: acc)
            | _ => malformed ()
        end
      val (_, acc) = List.foldl one (0, []) (String.fields (fn c => c = #"\n") text)
    in
      {path = path, title = !title, intro = !intro, annotations = List.rev acc}
    end

  (* glob against text. * is any run of characters, ? any one, [abc] [a-z]
     [!a] one of a set. openEnded: the text goes on with something that is
     not known, so that a glob that matches it so far matches. *)
  fun matches (glob : string, text : string, openEnded : bool) : bool =
    let
      val g = String.size glob
      val t = String.size text
      (* the set that begins at i, after the bracket: whether c is in it and
         where the glob goes on; NONE when the bracket is never closed *)
      fun set (i, c) =
        let
          val negated = i < g andalso String.sub (glob, i) = #"!"
          fun scan (k, found, first) =
            if k >= g then NONE
            else if String.sub (glob, k) = #"]" andalso not first then SOME (found <> negated, k + 1)
            else if k + 2 < g andalso String.sub (glob, k + 1) = #"-" andalso String.sub (glob, k + 2) <> #"]" then
              scan (k + 3, found orelse (String.sub (glob, k) <= c andalso c <= String.sub (glob, k + 2)), false)
            else scan (k + 1, found orelse String.sub (glob, k) = c, false)
        in
          scan (if negated then i + 1 else i, false, true)
        end
      fun go (i, j) =
        if j = t andalso openEnded then true
        else if i = g then j = t
        else
          case String.sub (glob, i) of
            #"*" => go (i + 1, j) orelse (j < t andalso go (i, j + 1))
          | #"?" => j < t andalso go (i + 1, j + 1)
          | #"[" =>
              j < t andalso
              (case set (i + 1, String.sub (text, j)) of
                 SOME (inSet, i') => inSet andalso go (i', j + 1)
               | NONE => String.sub (text, j) = #"[" andalso go (i + 1, j + 1))
          | c => j < t andalso c = String.sub (text, j) andalso go (i + 1, j + 1)
    in
      go (0, 0)
    end

  (* What is said about each member, by its name with the structure
     (`List.take`): whom it is about and the text, in the order of the file,
     each once. members: every such name that the pages show. An annotation
     that belongs to no member of them is an error: it is stale, or about
     something that is not documented. *)
  fun byMember ({annotations, ...} : file, sites : DocTests.site list option, members : string list)
      : (string * string) list StringMap.map =
    let
      val known = List.foldl (fn (m, s) => StringMap.insert (s, m, ())) StringMap.empty members
      (* the cases of a suite by their scope; a case that is computed is what
         is known of it, its beginning, and may be nothing *)
      val byScope =
        case sites of
          NONE => StringMap.empty
        | SOME ss =>
            List.foldl (fn (s : DocTests.site, m) =>
                          let
                            val c = #case' s
                            val c = if #computed s andalso String.isSuffix "*" c then String.substring (c, 0, String.size c - 1) else c
                          in
                            StringMap.insert (m, #scope s, (c, #computed s, Option.getOpt (#via s, #file s))
                                                           :: Option.getOpt (StringMap.find (m, #scope s), []))
                          end)
                       StringMap.empty ss
      val scopes = List.filter (fn s => StringMap.member (known, s)) (List.map #1 (StringMap.listItemsi byScope))
      fun casesOf scope = Option.getOpt (StringMap.find (byScope, scope), [])
      (* The members with a check that the glob names. A label that is written
         out decides; a computed one counts when the glob agrees with the
         beginning that is known, and one of which nothing is known only when
         the glob would name no member otherwise and there is reason to take
         it (below). *)
      fun isWild c = c = #"*" orelse c = #"?" orelse c = #"[" orelse c = #"]"
      (* ---- a check of which only the member is known ----
         Its label is computed in full, so whether the glob names it cannot
         be seen. It is taken to when there is reason to: the words of the
         glob's case are found at the beginning of a part of a string constant
         of the file that makes the label (`"whitespace-tab"` for the glob
         `whitespace-*`), and what the text says of `X.member` by name is
         said of the structures that begin with X only. A glob that writes
         the structure and the member out is taken at its word. *)
      val constants : string list StringMap.map ref = ref StringMap.empty
      fun constantsOf file =
        case StringMap.find (!constants, file) of
          SOME cs => cs
        | NONE =>
            let
              val toks = Lexer.tokenize (Source.load file) handle _ => Vector.fromList []
              val cs = Vector.foldr (fn ((Token.STRING c, _), acc) => c :: acc | (_, acc) => acc) [] toks
            in
              constants := StringMap.insert (!constants, file, cs); cs
            end
      fun wordsOf (caseGlob : string) : string list =
        List.filter (fn w => String.size w >= 3)
                    (String.tokens (fn c => isWild c orelse c = #"-")
                                   (* what stands between brackets is no word *)
                                   (let
                                      fun strip (cs, inSet, acc) =
                                        case cs of
                                          [] => String.implode (List.rev acc)
                                        | #"[" :: rest => strip (rest, true, #"*" :: acc)
                                        | #"]" :: rest => strip (rest, false, acc)
                                        | c :: rest => strip (rest, inSet, if inSet then acc else c :: acc)
                                    in strip (String.explode caseGlob, false, []) end))
      fun begins (word : string, constant : string) : bool =
        let val last = List.last (String.fields (fn c => c = #"/") constant)
        in List.exists (String.isPrefix word) (String.fields (fn c => c = #"-") last) end
      fun fileMakes (file : string, caseGlob : string) : bool =
        let val cs = constantsOf file
        in List.all (fn w => List.exists (fn c => begins (w, c)) cs) (wordsOf caseGlob) end
      (* the structures X of which the text speaks as `X.member` *)
      fun spokenOf (text : string, member : string) : string list =
        List.mapPartial (fn t =>
                           let val parts = String.fields (fn c => c = #".") t
                           in
                             if List.length parts >= 2 andalso List.last parts = member
                             then SOME (String.concatWith "." (List.take (parts, List.length parts - 1)))
                             else NONE
                           end)
                        (String.tokens (fn c => not (Char.isAlphaNum c orelse c = #"." orelse c = #"_" orelse c = #"'")) text)
      fun withSuite (glob, text) =
        let
          val (scopeGlob, caseGlob) = case DocTests.split glob of SOME (s, c) => (s, SOME c) | NONE => (glob, NONE)
          (* what a scope must begin and end with, so that most are not looked at twice *)
          val (front, rest) = Substring.splitl (not o isWild) (Substring.full scopeGlob)
          val front = Substring.string front
          val back = if Substring.isEmpty rest orelse not (isSome caseGlob) then ""
                      else Substring.string (Substring.taker (not o isWild) rest)
          val candidates =
            if Substring.isEmpty rest andalso isSome caseGlob
            then (if StringMap.member (known, scopeGlob) andalso StringMap.member (byScope, scopeGlob) then [scopeGlob] else [])
            else List.filter (fn scope => (String.isPrefix front scope orelse String.isPrefix scope front)
                                          andalso String.isSuffix back scope) scopes
          (* whether the text, where it names structures for this member, names this one *)
          fun spoken scope =
            let
              val parts = String.fields (fn c => c = #".") scope
              val structure' = String.concatWith "." (List.take (parts, List.length parts - 1))
            in
              case spokenOf (text, List.last parts) of
                [] => true
              | xs => List.exists (fn x => String.isPrefix x structure') xs
            end
          fun named sure scope =
            case caseGlob of
              NONE => List.exists (fn (c, computed, _) => not computed andalso matches (glob, scope ^ "/" ^ c, false)) (casesOf scope)
            | SOME cg =>
                matches (scopeGlob, scope, false)
                andalso List.exists (fn (c, computed, file) =>
                                       if not computed then matches (cg, c, false)
                                       else if c = "" then
                                         (* a glob that writes the member out needs no more reason *)
                                         not sure andalso (Substring.isEmpty rest orelse (fileMakes (file, cg) andalso spoken scope))
                                       else matches (cg, c, true))
                                    (casesOf scope)
        in
          case List.filter (named true) candidates of
            [] => List.filter (named false) candidates
          | ms => ms
        end
      (* the members that a glob names; one glob is often on several lines *)
      val cache : string list StringMap.map ref = ref StringMap.empty
      fun membersOf (glob, text) =
        case StringMap.find (!cache, glob ^ "\t" ^ text) of
          SOME ms => ms
        | NONE =>
            let
              val ms =
                case sites of
                  SOME _ => withSuite (glob, text)
                | NONE =>
                    let val scopeGlob = case DocTests.split glob of SOME (s, _) => s | NONE => glob
                    in List.filter (fn m => matches (scopeGlob, m, false)) members end
            in
              cache := StringMap.insert (!cache, glob ^ "\t" ^ text, ms); ms
            end
      fun add (a : annotation, m) =
        case membersOf (#glob a, #text a) of
          [] => (DocDiag.error (#span a, "`" ^ #glob a ^ "` is the label of no check of a documented member"); m)
        | ms =>
            List.foldl (fn (member, m) =>
                          let val sofar = Option.getOpt (StringMap.find (m, member), [])
                          in
                            if List.exists (fn x => x = (#about a, #text a)) sofar then m
                            else StringMap.insert (m, member, sofar @ [(#about a, #text a)])
                          end)
                       m ms
    in
      List.foldl add StringMap.empty annotations
    end
end

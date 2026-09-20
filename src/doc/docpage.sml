(* The page of a signature (docs/plans/docgen.md, D8), as Markdown: a status
   table, the synopsis, the overview from the signature's comment, a line of
   contents, the interface with every identifier linked down the page, and
   the entries under their section headings. An entry is a heading with an
   explicit anchor, the specification, and what the comment says, the
   reserved paragraphs each in their own form; a datatype has a table of its
   constructors and a record one of its fields. *)
structure DocPage =
struct
  structure I = DocIR
  structure T = DocText
  structure M = DocMarkdown
  structure R = DocResolve

  (* What a page is rendered with. root: from the page's directory to the
     root of the output ("../"); up: from there to the directory the source
     paths are relative to. links: every link written, as (page, anchor) from
     the root, for the check that it leads somewhere. anchors: every anchor
     written, as (page, anchor). *)
  type env = {index : R.index, root : string, up : string,
              claims : DocClaims.claim list,
              (* the signatures that are documented in full: what is a warning elsewhere is an error there *)
              ratchet : string -> bool,
              (* the top-level name that a member of a signature also has, through a structure that implements it *)
              topLevel : string * string -> string option,
              (* the notes of a structure's body, and of the functor it applies, by member *)
              notesOf : string -> (string * I.doc) list,
              links : (string * string * Source.span) list ref,
              anchors : (string * string * Source.span) list ref}

  fun href (env : env, from : string, {page, anchor} : R.target, span : Source.span) : string =
    (#links env := (page, anchor, span) :: !(#links env);
     if page = from andalso anchor = "" then List.last (String.fields (fn c => c = #"/") page)
     else (if page = from then "" else #root env ^ page) ^ (if anchor = "" then "" else "#" ^ anchor))

  (* A path without `dir/..` in it. *)
  fun normalise (path : string) : string =
    let
      fun go ([], acc) = List.rev acc
        | go (".." :: rest, a :: acc) = if a = ".." then go (rest, ".." :: a :: acc) else go (rest, acc)
        | go ("." :: rest, acc) = go (rest, acc)
        | go (c :: rest, acc) = go (rest, c :: acc)
    in
      String.concatWith "/" (go (String.fields (fn c => c = #"/") path, []))
    end

  (* ---- counting ---- *)
  fun entriesOf (items : I.item list) : I.entryRecord list =
    List.concat (List.map (fn I.Item (I.Entry e) =>
                                (if #kind e = I.Include orelse #kind e = I.Sharing then [] else [e])
                                @ (case #body e of SOME inner => entriesOf inner | NONE => [])
                            | _ => []) items)

  fun isDocumented (e : I.entryRecord) : bool = not (List.null (#doc e)) orelse isSome (#leader e)

  (* A value whose type shows an arrow is expected to have a usage head. *)
  fun isFunction (e : I.entryRecord) : bool =
    #kind e = I.Val andalso String.isSubstring "->" (#spec e)

  fun reserved (doc : I.doc, keyword : string) : T.inline list list =
    List.mapPartial (fn T.Reserved {keyword = k, body, ...} => if k = keyword then SOME body else NONE | _ => NONE) doc

  fun statusOf (doc : I.doc) : string =
    case reserved (doc, "Status") of body :: _ => T.plain body | [] => "required"

  fun areaOf (doc : I.doc) : string option =
    case reserved (doc, "Area") of body :: _ => SOME (T.plain body) | [] => NONE

  (* The first paragraph on one line: the summary of index pages. *)
  fun summaryOf (doc : I.doc) : T.inline list =
    case List.find (fn T.Para _ => true | _ => false) doc of
      SOME (T.Para is) => is
    | _ => []

  (* ---- the blocks of a comment ---- *)
  fun blocks (env : env, page : string, sigName : string, path : string list, args : string list, span : Source.span)
             (doc : I.doc) : string =
    let
      fun link c =
        case R.resolve (#index env, sigName, path, args) c of
          R.Target t => SOME (href (env, page, t, span))
        | R.Unresolved =>
            ((if #ratchet env sigName then DocDiag.error else DocDiag.warn)
               (span, "`" ^ c ^ "` names nothing that is documented"); NONE)
        | _ => NONE
      val inl = M.inlines link
      fun labelled (label, body) = "**" ^ label ^ "** " ^ inl body ^ "\n\n"
      fun quoted s = String.concatWith "\n" (List.map (fn l => if l = "" then ">" else "> " ^ l)
                                                      (String.fields (fn c => c = #"\n") s)) ^ "\n\n"
      fun one b =
        case b of
          T.Reserved {keyword, modifier, body} =>
            (case keyword of
               "Raises" =>
                 ((case T.firstCode body of
                     SOME exn =>
                       (case R.resolve (#index env, sigName, path, args) exn of
                          R.Target _ => ()
                        | _ => if #ratchet env sigName
                               then DocDiag.error (span, "`Raises:` names `" ^ exn ^ "`, which is no exception that is documented")
                               else ())
                   | NONE => ());
                  labelled ("Raises", body))
             | "Law" => labelled ("Law", body)
             | "Example" => labelled ("Example", body)
             | "Complexity" => labelled ("Complexity", body)
             | "See also" => labelled ("See also", body)
             | "Area" => ""
             | "Status" => ""
             | "Implements" => ""
             | "Pinned by" => ""
             | _ =>
                 if T.isNote keyword then
                   quoted ("**" ^ keyword ^ "**" ^ (case modifier of SOME m => " (" ^ M.escape m ^ ")" | NONE => "") ^ " " ^ inl body)
                 else "")
        | _ => M.block link b
    in
      String.concat (List.map one doc)
    end

  (* The text of a comment in a table cell. *)
  fun cellOf (env : env, page, sigName, path, args, span) (doc : I.doc) : string =
    let
      fun link c =
        case R.resolve (#index env, sigName, path, args) c of
          R.Target t => SOME (href (env, page, t, span))
        | _ => NONE
    in
      String.concatWith "<br><br>"
        (List.mapPartial (fn T.Para is => SOME (M.cell link is)
                           | T.Reserved {keyword, body, ...} =>
                               if T.isNote keyword orelse keyword = "Example" orelse keyword = "See also"
                               then SOME ("**" ^ keyword ^ "** " ^ M.cell link body) else NONE
                           | T.CodeBlock c => SOME (M.code (T.oneLine c))
                           | T.Bullets items => SOME (String.concatWith "<br>" (List.map (fn is => "&bull; " ^ M.cell link is) items)))
                         doc)
    end

  fun mark (env : env, page : string, binding : I.binding, span : Source.span) : string =
    let val a = DocAnchor.anchor binding
    in #anchors env := (page, a, span) :: !(#anchors env); M.anchor a end

  (* ---- entries ---- *)
  fun headingLevel (path : string list) : string = if List.null path then "### " else "#### "

  fun fieldRows (env : env, page, sigName, owner : string list, span) (fields : I.field list) : string list list =
    List.map (fn {label, ty, doc} : I.field =>
                [mark (env, page, {bound = I.BField, path = owner, name = label}, span) ^ M.code label,
                 M.cell (fn _ => NONE) [T.Code ty],
                 cellOf (env, page, sigName, owner, [], span) doc]) fields

  (* An entry with the entries documented with it (those it leads). *)
  fun entry (env : env, page : string, sigName : string) (e : I.entryRecord, followers : I.entryRecord list) : string =
    let
      val group = e :: followers
      val path = #path e
      val span = #span e
      val args = List.concat (List.map (fn g : I.entryRecord => List.concat (List.map #args (#heads g))) group)
      val names = String.concatWith ", " (List.map (fn g : I.entryRecord => M.code (#name g)) group)
      val marks = String.concat (List.map (fn g : I.entryRecord =>
                                             mark (env, page, {bound = I.BEntry (#kind g), path = #path g, name = #name g}, #span g))
                                          group)
      val spec = M.fenced ("sml", String.concatWith "\n" (List.map #spec group))
      val consTable =
        if List.null (#cons e) then ""
        else
          M.table (["Constructor", "Argument", "Description"],
                   List.concat
                     (List.map (fn {name, arg, fields, doc} : I.con =>
                                  [mark (env, page, {bound = I.BCon, path = path, name = name}, span) ^ M.code name,
                                   (case arg of SOME t => M.cell (fn _ => NONE) [T.Code t] | NONE => ""),
                                   cellOf (env, page, sigName, path, [], span) doc]
                                  :: List.map (fn row => case row of
                                                           [l, t, d] => ["&nbsp;&nbsp;&nbsp;&nbsp;" ^ l, t, d]
                                                         | _ => row)
                                              (fieldRows (env, page, sigName, path @ [name], span) fields))
                               (#cons e)))
      val fieldTable =
        if List.null (#fields e) then ""
        else M.table (["Field", "Type", "Description"], fieldRows (env, page, sigName, path @ [#name e], span) (#fields e))
      val inner =
        case #body e of
          SOME items => items' (env, page, sigName) items
        | NONE => ""
      (* the notes that the implementations have on these members *)
      val instanceNotes =
        String.concat
          (List.map (fn c : DocClaims.claim =>
                       String.concat
                         (List.map (fn (member, doc) =>
                                      if List.exists (fn g : I.entryRecord =>
                                                        String.concatWith "." (#path g @ [#name g]) = member) group
                                      then "In " ^ M.code (#name c) ^ ":\n\n" ^ blocks (env, page, sigName, path, args, #span c) doc
                                      else "")
                                   (#notesOf env (#name c))))
                    (List.filter (fn c : DocClaims.claim => #signat c = sigName andalso not (#isFunctor c)) (#claims env)))
    in
      headingLevel path ^ marks ^ names ^ "\n\n"
      ^ (if #kind e = I.Structure andalso isSome (#body e) then "" else spec)
      ^ (case (#kind e, #sigref e) of
           (I.Structure, SOME s) =>
             if StringMap.member (#signatures (#index env), s)
             then "A substructure: its members are described on the page of ["
                  ^ M.code s ^ "](" ^ href (env, page, {page = R.sigPage s, anchor = ""}, span) ^ ").\n\n"
             else ""
         | _ => "")
      ^ blocks (env, page, sigName, path, args, span) (#doc e)
      ^ consTable ^ fieldTable
      ^ (case List.mapPartial (fn g : I.entryRecord =>
                                 if List.null (#path g) then #topLevel env (sigName, #name g) else NONE) group of
           [] => ""
         | tops => "Also in the [top-level environment](" ^ #root env ^ "top-level.md): "
                   ^ String.concatWith ", " (List.map M.code tops) ^ ".\n\n")
      ^ instanceNotes ^ inner
    end

  (* The items of a body: sections, prose, and entries with their followers. *)
  and items' (env : env, page : string, sigName : string) (items : I.item list) : string =
    let
      fun go [] = []
        | go (I.Section title :: rest) = ("## " ^ M.escape title ^ "\n\n") :: go rest
        | go (I.Prose doc :: rest) = blocks (env, page, sigName, [], [], Source.noSpan) doc :: go rest
        | go (I.Item (I.Entry e) :: rest) =
            if #kind e = I.Sharing then go rest
            else if #kind e = I.Include then includeNote e :: go rest
            else
              let
                fun follows (I.Item (I.Entry f)) = #leader f = SOME (#name e)
                  | follows _ = false
                fun take (l, acc) = case l of x :: xs => if follows x then take (xs, x :: acc) else (List.rev acc, l)
                                            | [] => (List.rev acc, [])
                val (fs, rest') = take (rest, [])
              in
                entry (env, page, sigName) (e, List.map (fn I.Item (I.Entry f) => f | _ => e) fs) :: go rest'
              end
      (* `include S`: what is inherited, each member with its summary and a
         link to where it is described *)
      and includeNote (e : I.entryRecord) =
        case #sigref e of
          SOME s =>
            let
              val known = StringMap.member (#signatures (#index env), s)
              val target = if known
                           then "[" ^ M.code s ^ "](" ^ href (env, page, {page = R.sigPage s, anchor = ""}, #span e) ^ ")"
                           else M.code s
              val inherited = if known then entriesOf (R.bodyOf (#index env, s)) else []
              fun row (m : I.entryRecord) =
                ["[" ^ M.code (String.concatWith "." (#path m @ [#name m])) ^ "]("
                 ^ href (env, page, {page = R.sigPage s,
                                     anchor = DocAnchor.anchor {bound = I.BEntry (#kind m), path = #path m, name = #name m}},
                         #span e) ^ ")",
                 I.kindName (#kind m),
                 M.cell (fn _ => NONE) (summaryOf (#doc m))]
            in
              "**Included from " ^ target ^ "**: " ^ M.code (#spec e) ^ "\n\n"
              ^ blocks (env, page, sigName, #path e, [], #span e) (#doc e)
              ^ (if List.null inherited then "" else M.table (["Member", "", ""], List.map row inherited))
            end
        | NONE => (case #body e of SOME inner => items' (env, page, sigName) inner | NONE => "")
    in
      String.concat (go items)
    end

  (* ---- the interface ---- *)
  fun interface (env : env, page : string, pieces : I.piece list, span : Source.span) : string =
    "<pre>\n"
    ^ String.concat (List.map (fn (text, NONE) => M.escapeHtml text
                                | (text, SOME b) =>
                                    "<a href=\"" ^ href (env, page, {page = page, anchor = DocAnchor.anchor b}, span) ^ "\">"
                                    ^ M.escapeHtml text ^ "</a>") pieces)
    ^ "\n</pre>\n\n"

  fun sections (items : I.item list) : string list =
    List.mapPartial (fn I.Section t => SOME t | _ => NONE) items

  (* GitHub's anchor of a heading: lowercased, punctuation dropped, blanks to
     hyphens. Section titles are ours, so this is safe for them. *)
  fun headingAnchor (title : string) : string =
    String.translate (fn c => if Char.isAlphaNum c then String.str (Char.toLower c)
                              else if c = #" " orelse c = #"-" then "-" else "") title

  (* ---- the page ---- *)
  fun signaturePage (env : env, library : string)
                    ({name, file, span, doc, interface = pieces, sigexp, body, ...} : I.signatureRecord) : string =
    let
      val page = R.sigPage name
      val es = entriesOf body
      val documented = List.length (List.filter isDocumented es)
      val area = areaOf doc
      val overview = List.filter (fn T.Reserved {keyword = "See also", ...} => false | _ => true) doc
      val seeAlso = reserved (doc, "See also")
      val titles = sections body
      val contents =
        if List.null titles then ""
        else "## Contents\n\n"
             ^ String.concatWith " &middot;\n" (List.map (fn t => "[" ^ M.escape t ^ "](#" ^ headingAnchor t ^ ")") titles) ^ "\n\n"
      fun link c =
        case R.resolve (#index env, name, [], []) c of
          R.Target t => SOME (href (env, page, t, span))
        | _ => NONE
      (* the implementations, by name *)
      fun insert (c : DocClaims.claim, []) = [c]
        | insert (c, c' :: rest) = if #name c < #name c' then c :: c' :: rest else c' :: insert (c, rest)
      val mine = List.foldl insert [] (List.filter (fn c : DocClaims.claim => #signat c = name) (#claims env))
      fun statusOfClaim (c : DocClaims.claim) = case #status c of SOME st => st | NONE => statusOf doc
    in
      "# signature " ^ name ^ "\n\n"
      ^ "[" ^ M.escape library ^ "](" ^ #root env ^ "README.md)"
      ^ (case area of SOME a => " &rsaquo; " ^ M.escape a | NONE => "") ^ " &rsaquo; **" ^ name ^ "**\n\n"
      ^ M.table (["", ""],
                 [["Status", M.escape (statusOf doc)],
                  ["Implementations", if List.null mine then "none" else Int.toString (List.length mine)],
                  ["Documentation", Int.toString documented ^ " of " ^ Int.toString (List.length es) ^ " entries documented"],
                  ["Source", "[" ^ M.escape (normalise file) ^ "](" ^ #root env ^ #up env ^ normalise file ^ ")"]])
      ^ "## Synopsis\n\n"
      ^ M.fenced ("sml", String.concatWith "\n"
                          (("signature " ^ name ^ (case sigexp of SOME s => " = " ^ s | NONE => ""))
                           :: List.map (fn c : DocClaims.claim =>
                                          (if #isFunctor c then "functor " ^ #name c ^ " (...)" else "structure " ^ #name c)
                                          ^ (if #opaque c then " :> " else " : ") ^ name
                                          ^ (if #realisations c = "" then "" else " " ^ #realisations c)
                                          ^ (if statusOfClaim c = "required" then "" else "  (* " ^ statusOfClaim c ^ " *)"))
                                       mine))
      ^ (if List.null mine then ""
         else M.table (["Implementation", "", "Source"],
                       List.map (fn c : DocClaims.claim =>
                                   [M.code (#name c), M.cell link (#summary c),
                                    "[" ^ M.escape (normalise (#file c)) ^ "](" ^ #root env ^ #up env ^ normalise (#file c) ^ ")"])
                                mine))
      ^ blocks (env, page, name, [], [], span) overview
      ^ contents
      ^ (if List.null pieces orelse isSome sigexp then "" else "## Interface\n\n" ^ interface (env, page, pieces, span))
      ^ items' (env, page, name) body
      ^ (if List.null seeAlso then ""
         else "## See also\n\n" ^ String.concatWith " &middot; " (List.map (M.inlines link) seeAlso) ^ "\n\n")
      ^ "---\n\n<sub>Generated by runedoc from " ^ M.escape (normalise file) ^ "; do not edit.</sub>\n"
    end
end

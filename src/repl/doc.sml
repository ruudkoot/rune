(* `:doc` (docs/plans/repl.md, M8): the documentation of the Basis Library as
   runedoc wrote it for programs to read (docs/generated/basis/members.json,
   DocSite.membersIndex), read once before the REPL's image is saved, and
   shown with its Markdown rendered for the terminal by lib/markdown, in the
   palette's roles. A name is a member of a structure (`List.map`,
   `Posix.FileSys.chmod`), a structure or a signature, or a value of the top
   level that is a structure's member under another name (`map`, which is
   `List.map`). *)
structure ReplDoc =
struct
  type member = {kind : string, name : string, spec : string, doc : string, page : string}
  type signat = {doc : string, page : string, members : member list}

  val signatures : signat StringMap.map ref = ref StringMap.empty
  (* each public structure's signature *)
  val structures : string StringMap.map ref = ref StringMap.empty

  fun field (name : string, v : Json.value) : string =
    case Json.member (name, v) of SOME (Json.String s) => s | _ => ""

  (* the index read; nothing where it cannot be *)
  fun load (file : string) : unit =
    let
      val ins = TextIO.openIn file
      val v = Json.decode (TextIO.inputAll ins) before TextIO.closeIn ins
      fun memberOf m = {kind = field ("kind", m), name = field ("name", m), spec = field ("spec", m),
                        doc = field ("doc", m), page = field ("page", m)}
    in
      (case Json.member ("signatures", v) of
         SOME (Json.Object sigs) =>
           signatures := List.foldl (fn ((n, s), acc) =>
                                       StringMap.insert (acc, n, {doc = field ("doc", s), page = field ("page", s),
                                                                  members = case Json.member ("members", s) of
                                                                              SOME (Json.Array ms) => List.map memberOf ms
                                                                            | _ => []}))
                                    StringMap.empty sigs
       | _ => ());
      case Json.member ("structures", v) of
        SOME (Json.Object strs) =>
          structures := List.foldl (fn ((n, Json.String s), acc) => StringMap.insert (acc, n, s) | (_, acc) => acc)
                                   StringMap.empty strs
      | _ => ()
    end
    handle IO.Io _ => () | Json.Syntax _ => ()

  (* Markdown for the terminal, at the REPL's width and in its styles *)
  fun render (markdown : string) : string =
    let
      fun roleOf (r : Markdown.role) =
        case r of
          Markdown.Head _ => "doc.heading"
        | Markdown.Mono => "doc.code"
        | Markdown.Bold => "strong"
        | Markdown.Anchor _ => "doc.link"
        | Markdown.Quoted => "faint"
        | Markdown.Marker => "repl.ui"
        | Markdown.Ruler => "repl.ui"
        | Markdown.Italic => "text"
    in
      ReplFront.renderAs roleOf (Markdown.toDoc (Markdown.parse markdown))
    end

  fun paint role s = ReplFront.paint role s

  (* a specification, coloured as SML is where it is typed *)
  fun spec' (s : string) : string = ReplHighlight.paint (!ReplSession.env, s, ReplHighlight.code)

  fun showMember (structure' : string, sigName : string, {spec, doc, page, ...} : member) : string =
    spec' spec ^ "\n" ^ paint "repl.ui" ("  " ^ structure' ^ " : " ^ sigName ^ ", docs/generated/basis/" ^ page) ^ "\n"
    ^ (if doc = "" then "" else "\n" ^ render doc ^ "\n")

  fun memberOf (sigName : string, name : string) : member option =
    case StringMap.find (!signatures, sigName) of
      SOME {members, ...} => List.find (fn m => #name m = name andalso #kind m <> "include") members
    | NONE => NONE

  (* a structure's member: the longest structure the name begins with that
     has a signature, and the rest a member of it *)
  fun asMember (name : string) : string option =
    let
      val parts = String.fields (fn c => c = #".") name
      fun try k =
        if k <= 0 then NONE
        else
          let
            val structure' = String.concatWith "." (List.take (parts, k))
            val rest = String.concatWith "." (List.drop (parts, k))
          in
            case StringMap.find (!structures, structure') of
              SOME sigName => (case memberOf (sigName, rest) of
                                 SOME m => SOME (showMember (structure', sigName, m))
                               | NONE => try (k - 1))
            | NONE => try (k - 1)
          end
    in try (List.length parts - 1) end

  (* a signature, or a structure by its signature: its comment and the names
     it specifies *)
  fun asModule (name : string) : string option =
    let
      fun show (title, sigName) =
        case StringMap.find (!signatures, sigName) of
          SOME {doc, page, members} =>
            SOME (paint "doc.heading" title ^ "\n" ^ paint "repl.ui" ("  docs/generated/basis/" ^ page) ^ "\n\n"
                  ^ (if doc = "" then "" else render doc ^ "\n\n")
                  ^ String.concatWith "\n" (List.map (fn m => "  " ^ spec' (#spec m))
                                                     (List.filter (fn m => #kind m <> "include") members)) ^ "\n")
        | NONE => NONE
    in
      case StringMap.find (!structures, name) of
        SOME sigName => show ("structure " ^ name ^ " : " ^ sigName, sigName)
      | NONE => show ("signature " ^ name, name)
    end

  (* a value of the top level, by the structure's member it is *)
  fun asTopLevel (env : Env.env, name : string) : string option =
    case StringMap.find (Env.vals env, name) of
      SOME (Env.Val {stamp, ...}) =>
        StringMap.foldli
          (fn (structure', sigName, found) =>
             case found of
               SOME _ => found
             | NONE =>
                 case ReplShow.structureAt (env, String.fields (fn c => c = #".") structure') of
                   SOME e =>
                     (case StringMap.find (Env.vals e, name) of
                        SOME (Env.Val {stamp = s, ...}) =>
                          if s = stamp then
                            Option.map (fn m => showMember (structure', sigName, m)) (memberOf (sigName, name))
                          else NONE
                      | _ => NONE)
                 | NONE => NONE)
          NONE (!structures)
    | _ => NONE

  fun doc (env : Env.env, name : string) : string =
    if StringMap.numItems (!signatures) = 0 then raise Fail "the REPL was built without the Basis's documentation"
    else
      case asMember name of
        SOME s => s
      | NONE =>
          case asModule name of
            SOME s => s
          | NONE =>
              case asTopLevel (env, name) of
                SOME s => s
              | NONE => raise Fail ("no documentation of " ^ name ^ " (the Basis Library's names have it)")
end

(* The notes of a library (docs/plans/docgen.md, D5): how it reads its
   specification, where the specification is wrong, where the library departs
   from it, what it chooses where the choice is its own, what it lacks. A note
   is a reserved paragraph of a doc comment,

       Reading: `Char.fromString/unescaped-double-quote`. The page says ...

   and its id has the form of a test label. The checks that pin a note are
   those its `Pinned by:` paragraph lists, as labels or globs of labels, or
   the check whose label is the id. The notes are written to notes.tsv, which
   tests/basis/check-notes.sh compares with the deviations that the suite
   records: the documentation is the source, and the suite reads its export,
   not the other way round. *)
structure DocNotes =
struct
  structure I = DocIR
  structure T = DocText

  type note = {id : string, kind : string, differs : bool,
               block : T.block,               (* the paragraph itself, to show it again elsewhere *)
               signat : string,               (* the signature it is about, or "" *)
               member : string,               (* the member, with its substructures; "" for the whole *)
               structure' : string,           (* for a note of a structure's or functor's body *)
               globs : string list,           (* of `Pinned by:` *)
               text : T.inline list, file : string, span : Source.span}

  (* The notes among some blocks: each with the `Pinned by:` that follows it. *)
  fun ofDoc (doc : I.doc) : (T.block * string list) list =
    case doc of
      [] => []
    | (b as T.Reserved {keyword, ...}) :: rest =>
        if not (T.isNote keyword) then ofDoc rest
        else
          let
            val (globs, rest') =
              case rest of
                T.Reserved {keyword = "Pinned by", body = pins, ...} :: more =>
                  (List.mapPartial (fn T.Code c => SOME c | _ => NONE) pins, more)
              | _ => ([], rest)
          in
            (b, globs) :: ofDoc rest'
          end
    | _ :: rest => ofDoc rest

  fun make (signat, member, structure', file, span) (block, globs) : note =
    case block of
      T.Reserved {keyword, modifier, body} =>
        {id = Option.getOpt (T.firstCode body, ""), kind = keyword, differs = isSome modifier, block = block,
         signat = signat, member = member, structure' = structure', globs = globs, text = body,
         file = file, span = span}
    | _ => {id = "", kind = "", differs = false, block = block, signat = signat, member = member,
            structure' = structure', globs = globs, text = [], file = file, span = span}

  fun ofItems (signat : string, file : string) (items : I.item list) : note list =
    List.concat
      (List.map (fn I.Item (I.Entry e) =>
                      let
                        val member = String.concatWith "." (#path e @ [#name e])
                        val here = make (signat, member, "", file, #span e)
                      in
                        List.map here (ofDoc (#doc e))
                        @ List.concat (List.map (fn c : I.con => List.map here (ofDoc (#doc c))
                                                                 @ List.concat (List.map (fn f : I.field => List.map here (ofDoc (#doc f))) (#fields c)))
                                                (#cons e))
                        @ List.concat (List.map (fn f : I.field => List.map here (ofDoc (#doc f))) (#fields e))
                        @ (case #body e of SOME inner => ofItems (signat, file) inner | NONE => [])
                      end
                  | I.Prose doc => List.map (make (signat, "", "", file, Source.noSpan)) (ofDoc doc)
                  | I.Section _ => [])
                items)

  (* signatureOf: the signature that a public structure claims first. *)
  fun ofModules (isPublic : string -> bool, signatureOf : string -> string option) (modules : I.module list) : note list =
    let
      fun ofStruct prefix (r : I.structRecord) : note list =
        let
          val name = prefix ^ #name r
          val signat = Option.getOpt (signatureOf name, "")
        in
          if not (isPublic (#name r)) then []
          else
            List.map (make (signat, "", name, #file r, #span r)) (ofDoc (#doc r))
            @ List.concat (List.map (fn (member, doc) => List.map (make (signat, member, name, #file r, #span r)) (ofDoc doc))
                                    (#notes r))
            @ List.concat (List.map (fn I.Struct sub => ofStruct (name ^ ".") sub | _ => []) (#subs r))
        end
    in
      List.concat
        (List.map (fn I.Signature s =>
                        if not (isPublic (#name s)) then []
                        else List.map (make (#name s, "", "", #file s, #span s)) (ofDoc (#doc s))
                             @ ofItems (#name s, #file s) (#body s)
                    | I.Struct r => ofStruct "" r
                    | I.Functor {name, doc, notes, file, span, ...} =>
                        if not (isPublic name) then []
                        else List.map (make ("", "", name, file, span)) (ofDoc doc)
                             @ List.concat (List.map (fn (member, d) => List.map (make ("", member, name, file, span)) (ofDoc d)) notes)
                    | I.Decl _ => [])
                  modules)
    end

  (* ---- labels ---- *)
  (* glob against text: * is any run of characters. *)
  fun matches (glob : string, text : string) : bool =
    let
      val g = String.size glob
      val t = String.size text
      fun go (i, j) =
        if i = g then j = t
        else if String.sub (glob, i) = #"*" then go (i + 1, j) orelse (j < t andalso go (i, j + 1))
        else j < t andalso String.sub (glob, i) = String.sub (text, j) andalso go (i + 1, j + 1)
    in
      go (0, 0)
    end

  (* What pins a note: its globs, or its id when there are none. *)
  fun pinsOf (n : note) : string list = if List.null (#globs n) then [#id n] else #globs n

  (* The labels of a suite, by their scope (`List.take`), so that a glob whose
     scope is written out is compared with few of them. *)
  type labels = {byScope : string list StringMap.map, all : string list}

  fun labelsOf (sites : DocTests.site list) : labels =
    {byScope = List.foldl (fn (s : DocTests.site, m) =>
                             StringMap.insert (m, #scope s, #label s :: Option.getOpt (StringMap.find (m, #scope s), [])))
                          StringMap.empty sites,
     all = List.map #label sites}

  (* A label of the suite matches the glob; a computed label, which ends in a
     star, also when the glob begins as the label does. *)
  fun pinnedBy ({byScope, all} : labels) (glob : string) : bool =
    let
      val candidates =
        case DocTests.split glob of
          SOME (scope, _) =>
            if CharVector.exists (fn c => c = #"*") scope then all
            else Option.getOpt (StringMap.find (byScope, scope), [])
        | NONE => all
    in
      List.exists (fn l => matches (glob, l)
                           orelse (String.isSuffix "*" l andalso String.isPrefix (String.substring (l, 0, String.size l - 1)) glob))
                  candidates
    end

  fun isPinned (labels : labels) (n : note) : bool = List.exists (pinnedBy labels) (pinsOf n)

  (* The globs of `Pinned by:` must each match a check; an id need not. *)
  fun checkPins (labels : labels) (notes : note list) : unit =
    List.app (fn n : note =>
                List.app (fn g => if pinnedBy labels g then ()
                                  else DocDiag.error (#span n, "`Pinned by:` names `" ^ g ^ "`, and the suite has no check with such a label"))
                         (#globs n))
             notes

  (* Two notes with one id would make the id useless. *)
  fun checkIds (notes : note list) : unit =
    ignore (List.foldl (fn (n : note, seen) =>
                          if #id n = "" then seen
                          else if StringMap.member (seen, #id n)
                          then (DocDiag.error (#span n, "the note `" ^ #id n ^ "` is written twice; an id names one note"); seen)
                          else StringMap.insert (seen, #id n, ()))
                       StringMap.empty notes)

  (* id, kind, whether the suite differs, signature, member, structure, what
     pins it, whether a check does, source, text *)
  fun tsv (labels : labels option) (notes : note list) : string =
    String.concat
      ("id\tkind\tsuite\tsignature\tmember\tstructure\tpins\tpinned\tsource\ttext\n"
       :: List.map (fn n : note =>
                      String.concatWith "\t"
                        [#id n, #kind n, if #differs n then "differs" else "", #signat n, #member n, #structure' n,
                         String.concatWith " " (pinsOf n),
                         (case labels of SOME ls => if isPinned ls n then "yes" else "no" | NONE => ""),
                         #file n, T.plain (#text n)] ^ "\n")
                   notes)
end

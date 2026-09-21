(* The documentation of a library as a tree of files (docs/plans/docgen.md,
   D8): a page per signature, the overview, the index of identifiers, how to
   read a page, and what is documented so far. A library is a directory with
   a MANIFEST; what it provides, without the names that begin with Rune, is
   public. Everything is made in memory first: `write` puts it on disk and
   removes what it no longer makes, `check` only compares. *)
structure DocSite =
struct
  structure I = DocIR
  structure T = DocText
  structure M = DocMarkdown
  structure R = DocResolve
  structure P = DocPage

  type file = string * string          (* path from the root of the output, contents *)

  val pageLimit = 150000               (* GitHub renders larger pages lazily, or not at all *)

  fun isPublic (name : string) : bool = not (String.isPrefix "Rune" name)

  fun sort (less : 'a * 'a -> bool) (xs : 'a list) : 'a list =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if less (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (xs, a, b) = case xs of [] => (a, b) | x :: rest => split (rest, x :: b, a)
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split (xs, [], []) in merge (go (List.rev a), go (List.rev b)) end
    in
      go xs
    end


  (* ---- the library ---- *)
  (* A structure bound to itself under a signature, `structure List : LIST =
     List`: a seal file of the MANIFEST shows a program the structure as its
     signature has it. It declares nothing to document; what it hides is known
     from elaboration, which has the structure as the program sees it. *)
  fun isSeal (I.Struct {name, rhs = I.Alias other, ascription = SOME _, ...}) = name = other
    | isSeal _ = false

  (* The modules of the files of the MANIFEST, in its order. *)
  fun load (dir : string) : I.module list =
    List.concat (List.map (fn e : BasisManifest.entry =>
                             let val ms = List.filter (not o isSeal) (DocExtract.file (dir ^ "/" ^ #file e))
                             in
                               (* only a file that every program loads declares the top-level environment *)
                               if #when e = BasisManifest.Always then ms
                               else List.filter (fn I.Decl _ => false | _ => true) ms
                             end)
                          (BasisManifest.readManifest dir))

  fun signaturesOf (modules : I.module list) : I.signatureRecord list =
    List.mapPartial (fn I.Signature s => if isPublic (#name s) then SOME s else NONE | _ => NONE) modules

  (* The notes of the body of the structure at a path such as OS.Path, with
     those of the functor it applies: they hold for every application. *)
  fun notesOf (modules : I.module list) (path : string) : (string * I.doc) list =
    let
      fun functorNotes f =
        case List.find (fn I.Functor {name, ...} => name = f | _ => false) modules of
          SOME (I.Functor {notes, ...}) => notes
        | _ => []
      fun find (ms : I.module list, names) =
        case names of
          [] => []
        | n :: rest =>
            (case List.find (fn I.Struct {name, ...} => name = n | _ => false) ms of
               SOME (I.Struct {notes, subs, rhs, ...}) =>
                 if List.null rest then notes @ (case rhs of I.Apply (f, _) => functorNotes f | _ => [])
                 else find (subs, rest)
             | _ => [])
    in
      find (modules, String.fields (fn c => c = #".") path)
    end

  (* An environment for pages in the directory that `root` leads out of. *)
  fun envOf (modules : I.module list, out : string, ratchet : string list, sites : DocTests.site list,
             annotations : DocAnnot.file option) =
    let
      val tests = List.foldl (fn (s : DocTests.site, m) =>
                                StringMap.insert (m, #scope s, (case StringMap.find (m, #scope s) of
                                                                  SOME l => l @ [s] | NONE => [s])))
                             StringMap.empty sites
      val claims = DocClaims.ofModules isPublic modules
      val index = R.indexOf (modules, claims, isPublic)
      val links = ref []
      val anchors = ref []
      val declared = List.concat (List.map (fn I.Decl {names, ...} => names | _ => []) modules)
      (* what the annotations say, by the member of a structure: every member
         that a page shows is one of a signature that a structure claims, a
         constructor counts for its datatype, and `List:LIST` is the structure
         as a whole against its signature *)
      val annotated =
        case annotations of
          NONE => (DocAnnot.defaultTitle, fn _ => [])
        | SOME file =>
            let
              val members =
                List.concat (List.map (fn c : DocClaims.claim =>
                                         if #isFunctor c then []
                                         else (#name c ^ ":" ^ #signat c)
                                              :: List.concat
                                                   (List.map (fn e : I.entryRecord =>
                                                                List.map (fn n => String.concatWith "." (#name c :: #path e @ [n]))
                                                                         (#name e :: List.map #name (#cons e)))
                                                             (P.entriesOf (R.bodyOf (index, #signat c)))))
                                      claims)
              val found = DocAnnot.byMember (file, if List.null sites then NONE else SOME sites, members)
            in
              (#title file, fn member => Option.getOpt (StringMap.find (found, member), []))
            end
      (* a member that a structure implementing the signature declares to be
         the top-level name: `val null = null`, or a name the top level declares *)
      fun topLevel (sigName, member) =
        let
          fun ofStruct (I.Struct {name, twins, ...}) =
                if StringMap.find (#structures index, name) <> SOME sigName then NONE
                else
                  (case List.find (fn (m, _) => m = member) twins of
                     SOME (_, other) =>
                       if other = member orelse List.exists (fn d => d = other) declared then SOME other else NONE
                   | NONE => NONE)
            | ofStruct _ = NONE
          fun first [] = NONE
            | first (m :: ms) = (case ofStruct m of SOME t => SOME t | NONE => first ms)
        in
          first modules
        end
    in
      (claims, index,
       fn root => {index = index, root = root, up = out, claims = claims, notesOf = notesOf modules,
                   topLevel = topLevel, tests = tests, annotations = annotated,
                   ratchet = fn s => List.exists (fn r => r = s) ratchet,
                   links = links, anchors = anchors} : P.env)
    end

  (* ---- pages other than those of signatures ---- *)
  fun percent (a : int, b : int) : string = if b = 0 then "-" else Int.toString (a * 100 div b) ^ "%"

  fun capitalised (s : string) : string =
    if s = "" then s else String.str (Char.toUpper (String.sub (s, 0))) ^ String.extract (s, 1, NONE)

  (* The areas in the order in which the MANIFEST first has them; the
     signatures that name none come last. *)
  fun byArea (sigs : I.signatureRecord list) =
    let
      fun areaOf (s : I.signatureRecord) = P.areaOf (#doc s)
      val areas = List.foldl (fn (s, acc) =>
                                case areaOf s of
                                  SOME a => if List.exists (fn a' => a' = a) acc then acc else acc @ [a]
                                | NONE => acc) [] sigs
    in
      List.map (fn a => (SOME a, List.filter (fn s => areaOf s = SOME a) sigs)) areas
      @ (case List.filter (fn s => areaOf s = NONE) sigs of [] => [] | rest => [(NONE, rest)])
    end

  (* hasTypes: the page of the types that are one type is made (the library elaborates). *)
  fun readme (env : P.env, title : string, overview : I.doc, sigs : I.signatureRecord list,
              functors : (string * I.doc) list, letters : string list, hasTypes : bool) : string =
    let
      fun link c = case R.resolve (#index env, "", [], []) c of
                     R.Target t => SOME (P.href (env, "README.md", t, Source.noSpan))
                   | _ => NONE
      fun row (s : I.signatureRecord) =
        let val es = P.entriesOf (#body s)
        in
          ["[" ^ M.code (#name s) ^ "](" ^ P.href (env, "README.md", {page = R.sigPage (#name s), anchor = ""}, #span s) ^ ")",
           M.cell link (P.summaryOf (#doc s)),
           M.escape (P.statusOf (#doc s)),
           Int.toString (List.length (List.filter P.isDocumented es)) ^ " of " ^ Int.toString (List.length es)]
        end
      fun area (a, members) =
        "## " ^ (case a of SOME t => M.escape t | NONE => "Not yet assigned to an area") ^ "\n\n"
        ^ M.table (["Signature", "", "Status", "Documented"], List.map row members)
    in
      "# " ^ M.escape title ^ "\n\n"
      ^ String.concat (List.map (M.block link) overview)
      ^ "[How to read these pages](conventions.md) &middot; [the top-level environment](top-level.md)"
      ^ " &middot; [structures and what they implement](structures.md) &middot; [exceptions](exceptions.md)"
      ^ (if hasTypes then " &middot; [types that are one type](types.md)" else "")
      ^ " &middot; [readings of the specification](readings.md)"
      ^ " &middot; [what is documented](coverage.md) &middot; index: "
      ^ String.concatWith " " (List.map (fn l => "[" ^ l ^ "](index/" ^ l ^ ".md)") letters) ^ "\n\n"
      ^ String.concat (List.map area (byArea sigs))
      ^ (if List.null functors then ""
         else "## Functors\n\n"
              ^ M.table (["Functor", ""],
                         List.map (fn (name, doc) =>
                                     ["[" ^ M.code name ^ "](" ^ P.href (env, "README.md", {page = R.funPage name, anchor = ""}, Source.noSpan) ^ ")",
                                      M.cell link (P.summaryOf doc)]) functors))
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  fun coverage (sigs : I.signatureRecord list, unpinned : DocNotes.note list) : string =
    let
      fun counts (s : I.signatureRecord) =
        let
          val es = P.entriesOf (#body s)
          val fs = List.filter P.isFunction es
        in
          (List.length es, List.length (List.filter P.isDocumented es),
           List.length fs, List.length (List.filter (fn e => not (List.null (#heads e))) fs))
        end
      val rows = List.map (fn s : I.signatureRecord => (#name s, counts s)) sigs
      val (te, td, tf, th) = List.foldl (fn ((_, (e, d, f, h)), (te, td, tf, th)) => (te + e, td + d, tf + f, th + h))
                                        (0, 0, 0, 0) rows
      fun row (name, (e, d, f, h)) =
        ["[" ^ M.code name ^ "](" ^ R.sigPage name ^ ")", Int.toString e, Int.toString d, percent (d, e),
         Int.toString f, Int.toString h]
    in
      "# What is documented\n\n"
      ^ "An entry is a value, a type, an exception or a substructure that a signature specifies. It is\n"
      ^ "documented when a comment describes it, alone or together with the entry before it. A function\n"
      ^ "(a value whose type shows an arrow) is expected to begin its description with a usage head.\n\n"
      ^ M.table (["Signature", "Entries", "Documented", "", "Functions", "With a usage head"],
                 List.map row rows @ [["**all**", Int.toString te, Int.toString td, percent (td, te), Int.toString tf, Int.toString th]])
      ^ (case List.filter (fn (_, n) => n > 0) (List.map (fn s : I.signatureRecord => (#name s, List.length (DocExamples.ofSignature s))) sigs) of
           [] => ""
         | withExamples =>
             "## Examples that are run\n\n"
             ^ "An example that is an equation, `e = v`, is elaborated when these pages are made and tried by the\n"
             ^ "test suite: " ^ Int.toString (List.foldl (fn ((_, n), t) => n + t) 0 withExamples) ^ " of them, in "
             ^ String.concatWith ", " (List.map (fn (name, n) => "[" ^ M.code name ^ "](" ^ R.sigPage name ^ ") (" ^ Int.toString n ^ ")")
                                                withExamples)
             ^ ".\n\n")
      ^ (if List.null unpinned then ""
         else "## Notes that no check pins\n\n"
              ^ "A deviation or a limitation that the test suite does not show. A reading or an erratum need not\n"
              ^ "be pinned: many are about the text and not about behaviour.\n\n"
              ^ String.concat (List.map (fn n : DocNotes.note =>
                                           "- " ^ M.code (#id n) ^ " (" ^ M.escape (#kind n) ^ ")"
                                           ^ (if #signat n = "" then "" else ", " ^ #signat n)
                                           ^ (if #structure' n = "" then "" else ", in " ^ M.code (#structure' n)) ^ "\n") unpinned)
              ^ "\n")
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  (* annotated: the title of the block of annotations and what the file says
     they are, when the pages have them. *)
  fun conventions (annotated : (string * string) option) : string =
    "# How to read these pages\n\n"
    ^ "There is a page for every signature. A structure is documented by the signature it implements:\n"
    ^ "`List.map` is on the page of `LIST`.\n\n"
    ^ "## A page\n\n"
    ^ "- The table at the top says whether the specification requires the signature, how much of it is\n"
    ^ "  documented, and where its source is.\n"
    ^ "- **Synopsis**: the signature's declaration, then what its comment says about it as a whole.\n"
    ^ "- **Interface**: the text of the signature; every identifier leads to its entry.\n"
    ^ "- The entries, in the order of the source and under its section headings. An entry shows the\n"
    ^ "  specification and then its description, which for a function begins with the function applied\n"
    ^ "  to arguments, such as `take (l, i)`: those names are the names of the arguments in what follows.\n"
    ^ "  **Raises** names an exception and says when it is raised; **Law** is an equation that holds;\n"
    ^ "  **Example**, **Complexity** and **See also** are what they say. An example that is an equation,\n"
    ^ "  `e = v`, is more than an illustration: it is compiled when the pages are made, with the members of\n"
    ^ "  the signature in scope, and the test suite tries it.\n"
    ^ "- A datatype has a table of its constructors, a record one of its fields.\n"
    ^ "- A quoted block is a note on how the library reads its specification: a **Reading** of text that is\n"
    ^ "  silent, ambiguous or contradictory, an **Erratum** of the specification, a **Deviation** of the\n"
    ^ "  library from it, a choice the specification leaves to the **Implementation**, a **Limitation**.\n"
    ^ "  The identifier after the word names the note, and the check of the test suite that pins it\n"
    ^ "  when there is one.\n"
    ^ "- **Tests**, folded: the checks of the test suite whose labels name the member, by the structure\n"
    ^ "  they are written for, or by the test functor and the structures it is applied to.\n"
    ^ (case annotated of
         SOME (title, intro) =>
           "- **" ^ M.escape title ^ "**, folded, is not from the comments of the library"
           ^ (if intro = "" then "." else ": " ^ M.escape intro) ^ "\n"
       | NONE => "")
    ^ "\n"
    ^ "## Anchors\n\n"
    ^ "Every entry has an anchor `kind-name`, where the kind is one of `val`, `type`, `exn`, `con`\n"
    ^ "(constructor), `fld` (field) and `str` (substructure), and the name is in lower case. A prime is\n"
    ^ "spelled `-prime`. A member of a substructure has the substructure before its name\n"
    ^ "(`val-kind.file`), a field what it is a field of (`fld-failed.why`). A symbolic identifier is\n"
    ^ "spelled out, after `op-`, with these names: `val-op-at` is `@`, `con-op-colon-colon` is `::`.\n\n"
    ^ M.table (["Character", "Name"], List.map (fn (c, n) => [M.code c, n]) (DocAnchor.symbolTable ()))
    ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"

  (* ---- structures and functors ---- *)
  (* The names that a signature specifies at its top: values, types,
     exceptions, constructors and substructures, its includes followed. *)
  fun specified (index : R.index, sigName : string, seen : string list) : string list =
    List.concat
      (List.map (fn I.Item (I.Entry e) =>
                      (case (#kind e, #sigref e) of
                         (I.Include, SOME s) => if List.exists (fn s' => s' = s) seen then [] else specified (index, s, s :: seen)
                       | (I.Include, NONE) => []
                       | (I.Sharing, _) => []
                       | _ => #name e :: List.map (fn c : I.con => #name c) (#cons e))
                  | _ => [])
                (R.bodyOf (index, sigName)))

  (* namesOf: what elaboration knows a structure to declare, if the library
     was elaborated. *)
  (* strict: the library has a list of what is documented in full, and then a
     structure that shows a program more than its signatures name is an error:
     it needs a seal file in the MANIFEST. *)
  fun structuresPage (env : P.env, title : string, modules : I.module list, sigStatus : string -> string,
                      namesOf : (string list -> string list option) option, strict : bool) : string =
    let
      val claims = sort (fn (a : DocClaims.claim, b : DocClaims.claim) =>
                           case String.compare (#name a, #name b) of
                             LESS => true | GREATER => false | EQUAL => #signat a < #signat b)
                        (List.filter (fn c : DocClaims.claim => not (#isFunctor c)) (#claims env))
      fun structAt (ms : I.module list, names) =
        case names of
          [] => NONE
        | n :: rest =>
            (case List.find (fn I.Struct {name, ...} => name = n | _ => false) ms of
               SOME (I.Struct r) => if List.null rest then SOME r else structAt (#subs r, rest)
             | _ => NONE)
      fun definedAs (c : DocClaims.claim) =
        case structAt (modules, String.fields (fn ch => ch = #".") (#name c)) of
          SOME {rhs = I.Alias s, ...} => "is " ^ M.code s
        | SOME {rhs = I.Apply (f, _), ...} => "an application of " ^ M.code f
        | _ => ""
      fun sigLink s = "[" ^ M.code s ^ "](" ^ P.href (env, "structures.md", {page = R.sigPage s, anchor = ""}, Source.noSpan) ^ ")"
      fun row (c : DocClaims.claim) =
        [M.code (#name c), (if #opaque c then ":> " else ": ") ^ sigLink (#signat c),
         if #realisations c = "" then "" else M.code (#realisations c),
         (case #status c of SOME st => st | NONE => sigStatus (#signat c)),
         definedAs c,
         P.sourceLink (env, "", #file c)]
      (* What a structure declares beyond the signatures it claims: of a
         written-out structure what its body declares, in the order of the
         source; of one that is another by name, or an application of a
         functor, what elaboration finds in it. *)
      fun extras (c : DocClaims.claim) =
        let
          val path = String.fields (fn ch => ch = #".") (#name c)
          (* elaboration has the structure as a program sees it, sealed or
             not; without it, what the body of a written-out one declares *)
          val declared =
            case (namesOf, structAt (modules, path)) of
              (SOME f, _) => Option.getOpt (f path, [])
            | (NONE, SOME {members = SOME ms, ...}) => ms
            | _ => []
          (* what the signatures that a structure claims specify at a path
             below it: elaboration knows it with what is included and
             replicated, the syntax otherwise *)
          fun specifiedAt (names : string list, sub : string list) =
            List.concat
              (List.map (fn c' : DocClaims.claim =>
                           if #name c' <> String.concatWith "." names then []
                           else
                             case (if isSome namesOf then DocElab.specifiedBy (#signat c', sub) else NONE) of
                               SOME ns => ns
                             | NONE => if List.null sub then specified (#index env, #signat c', [#signat c']) else [])
                        claims)
          (* also what the signature of a structure around it specifies for it *)
          fun around n = if n >= List.length path then []
                         else specifiedAt (List.take (path, n), List.drop (path, n)) @ around (n + 1)
          val spec = specifiedAt (path, []) @ around 1
          val beyond = List.filter (fn m => not (List.exists (fn s => s = m) spec)) declared
          fun distinct xs = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else acc @ [x]) [] xs
        in
          distinct beyond
        end
      val firstClaims = List.foldl (fn (c : DocClaims.claim, acc) =>
                                      if List.exists (fn c' : DocClaims.claim => #name c' = #name c) acc then acc else acc @ [c])
                                   [] claims
      val beyondRows = List.mapPartial (fn c => case extras c of [] => NONE
                                                               | ms => SOME [M.code (#name c), String.concatWith ", " (List.map M.code ms)])
                                       firstClaims
      val () =
        if not strict then ()
        else List.app (fn c : DocClaims.claim =>
                         case extras c of
                           [] => ()
                         | ms => DocDiag.error (#span c, #name c ^ " shows a program " ^ String.concatWith ", " ms
                                                         ^ ", which " ^ #signat c ^ " does not name: bind it to its signature"
                                                         ^ " in a seal file of the MANIFEST"))
                      firstClaims
    in
      "# Structures and what they implement\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "Every public structure of the library that says which signature it implements. A structure is\n"
      ^ "documented on the page of its signature. `:>` means that the source seals the structure with the\n"
      ^ "signature, so that its types are its own; `:` that it matches it, which the test suite checks.\n"
      ^ "Either way a program sees the members that the signature names and no others, unless the structure\n"
      ^ "is listed at the end of this page.\n\n"
      ^ M.table (["Structure", "Signature", "Realisations", "Status", "", "Source"], List.map row claims)
      ^ (if List.null beyondRows then ""
         else "## Names beyond the signature\n\n"
              ^ "What a program can name in a structure although its signatures do not specify it: these structures\n"
              ^ "are not bound to their signature for the program. A program that uses such a name is not portable.\n\n"
              ^ M.table (["Structure", "Also declares"], beyondRows))
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  fun functorPage (env : P.env, title : string) (name, file, span, doc : I.doc, param, result : I.ascription option) : string =
    let
      val page = R.funPage name
      val mine = List.filter (fn c : DocClaims.claim => #isFunctor c andalso #name c = name) (#claims env)
    in
      "# functor " ^ name ^ "\n\n"
      ^ "[" ^ M.escape title ^ "](" ^ #root env ^ "README.md) &rsaquo; **" ^ name ^ "**\n\n"
      ^ M.table (["", ""],
                 [["Status", M.escape (case P.reserved (doc, "Status") of b :: _ => T.plain b | [] => "optional")],
                  ["Source", P.sourceLink (env, #root env, file)]])
      ^ "## Synopsis\n\n"
      ^ M.fenced ("sml", "functor " ^ name ^ " (" ^ param ^ ")"
                         ^ String.concat (List.map (fn c : DocClaims.claim =>
                                                      (if #opaque c then " :> " else " : ") ^ #signat c
                                                      ^ (if #realisations c = "" then "" else " " ^ #realisations c)) mine))
      ^ (case mine of
           [] => ""
         | cs => "Its result implements "
                 ^ String.concatWith ", " (List.map (fn c : DocClaims.claim =>
                                                       "[" ^ M.code (#signat c) ^ "]("
                                                       ^ P.href (env, page, {page = R.sigPage (#signat c), anchor = ""}, span) ^ ")") cs)
                 ^ ".\n\n")
      ^ P.blocks (env, page, "", [], [], span) doc
      ^ "---\n\n<sub>Generated by runedoc from " ^ M.escape (P.normalise file) ^ "; do not edit.</sub>\n"
    end

  (* ---- the top-level environment ---- *)
  (* The members of public structures that are a top-level name under another
     name: (top-level name, Structure.member, signature of the structure). *)
  fun twinsOfTop (env : P.env, modules : I.module list) : (string * string * string option) list =
    List.concat
      (List.map (fn I.Struct {name, twins, ...} =>
                      if not (isPublic name) then []
                      else List.mapPartial (fn (member, other) =>
                                              if CharVector.exists (fn c => c = #".") other then NONE
                                              else SOME (other, name ^ "." ^ member, StringMap.find (#structures (#index env), name)))
                                           twins
                  | _ => [])
                modules)

  fun topLevelPage (env : P.env, title : string, modules : I.module list) : string =
    let
      val page = "top-level.md"
      val twins = twinsOfTop (env, modules)
      val decls = List.mapPartial (fn I.Decl d => SOME d | _ => NONE) modules
      fun link c = case R.resolve (#index env, "", [], []) c of
                     R.Target t => SOME (P.href (env, page, t, Source.noSpan))
                   | _ => NONE
      fun sameAs name =
        String.concatWith ", "
          (List.mapPartial (fn (top, qualified, _) => if top = name then SOME (M.inlines link [T.Code qualified]) else NONE) twins)
      (* what the signature of a twin says about it, else the comment of the declaration *)
      fun describe (name, doc : I.doc) =
        case List.find (fn (top, _, s) => top = name andalso isSome s) twins of
          SOME (_, qualified, SOME s) =>
            let val member = List.last (String.fields (fn c => c = #".") qualified)
            in
              case List.find (fn e : I.entryRecord => #name e = member andalso List.null (#path e))
                             (P.entriesOf (R.bodyOf (#index env, s))) of
                SOME e => M.cell link (P.summaryOf (#doc e))
              | NONE => M.cell link (P.summaryOf doc)
            end
        | _ => M.cell link (P.summaryOf doc)
      fun rows kinds =
        List.concat (List.map (fn {kind, names, doc, ...} =>
                                 if List.exists (fn k => k = kind) kinds
                                 then List.map (fn n => [M.code n, sameAs n, describe (n, doc)])
                                               (if kind = "datatype" then [List.hd names] else names)
                                 else [])
                              decls)
      fun section (heading, kinds) =
        case rows kinds of [] => "" | rs => "## " ^ heading ^ "\n\n" ^ M.table (["", "Also", ""], rs)
      val infixes = List.filter (fn {kind, ...} => String.isPrefix "infix" kind) decls
      val overloads = List.filter (fn {kind, ...} => String.isPrefix "_overload" kind) decls
    in
      "# The top-level environment\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "What a program can name without a structure in front. The types `int`, `word`, `real`, `char`,\n"
      ^ "`string`, `bool`, `list`, `ref`, `array`, `vector`, `exn` and `unit`, the constructors of `bool`,\n"
      ^ "`list` and `ref`, the arithmetic and comparison operators and the exceptions of the language are\n"
      ^ "built into the compiler; the rest is declared by the files of the library that every program\n"
      ^ "loads, and is listed here. A value that is also a member of a structure is described on the page\n"
      ^ "of that structure's signature.\n\n"
      ^ section ("Types", ["type", "datatype"])
      ^ section ("Exceptions", ["exception"])
      ^ section ("Values", ["val"])
      ^ "## Infix identifiers\n\n"
      ^ M.table (["Identifiers", "Status"],
                 List.map (fn (names, status) => [String.concatWith " " (List.map M.code names), status])
                          ([(["*", "/", "div", "mod"], "infix 7"), (["+", "-", "^"], "infix 6"), (["::", "@"], "infixr 5"),
                            (["=", "<>", ">", ">=", "<", "<="], "infix 4"), ([":=", "o"], "infix 3"), (["before"], "infix 0")]
                           @ List.map (fn {kind, names, ...} => (names, kind)) infixes))
      ^ (if List.null overloads then ""
         else "## Types with overloaded constants and operators\n\n"
              ^ "The constants and the arithmetic of the language work at these types, besides the built-in\n"
              ^ "`int`, `word`, `real`, `char` and `string`.\n\n"
              ^ M.table (["Structure", "Class"],
                         List.map (fn {kind, names, ...} =>
                                     [String.concatWith " " (List.map M.code names),
                                      String.extract (kind, String.size "_overload ", NONE)]) overloads))
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  (* ---- the exceptions and who raises them ---- *)
  fun exceptionsPage (env : P.env, title : string, sigs : I.signatureRecord list) : string =
    let
      val page = "exceptions.md"
      val raised =
        List.concat
          (List.map (fn s : I.signatureRecord =>
                       List.concat
                         (List.map (fn e : I.entryRecord =>
                                      List.mapPartial (fn body => Option.map (fn exn => (exn, #name s, e)) (T.firstCode body))
                                                      (P.reserved (#doc e, "Raises")))
                                   (P.entriesOf (#body s))))
                    sigs)
      val names = sort (fn (a : string, b) => a < b)
                       (List.foldl (fn ((x, _, _), acc) => if List.exists (fn y => y = x) acc then acc else x :: acc) [] raised)
      fun line exn =
        "- " ^ M.code exn ^ ": "
        ^ String.concatWith ", "
            (List.mapPartial (fn (x, s, e : I.entryRecord) =>
                                if x <> exn then NONE
                                else SOME ("[" ^ M.code (String.concatWith "." (#path e @ [#name e])) ^ "]("
                                           ^ P.href (env, page, {page = R.sigPage s,
                                                                 anchor = DocAnchor.anchor {bound = I.BEntry (#kind e), path = #path e, name = #name e}},
                                                     #span e)
                                           ^ ") of " ^ s))
                             raised) ^ "\n"
    in
      "# Exceptions and who raises them\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "From the **Raises** paragraphs of the documented entries.\n\n"
      ^ String.concat (List.map line names)
      ^ "\n---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  (* ---- the index of identifiers ---- *)
  type occurrence = {name : string, kind : string, signat : string, anchor : string}

  fun occurrences (sigs : I.signatureRecord list) : occurrence list =
    List.concat
      (List.map (fn s : I.signatureRecord =>
                   List.concat
                     (List.map (fn e : I.entryRecord =>
                                  let
                                    val qualified = String.concatWith "." (#path e @ [#name e])
                                    fun occ (bound, path, name, shown) =
                                      {name = shown, kind = DocAnchor.kindPrefix bound, signat = #name s,
                                       anchor = DocAnchor.anchor {bound = bound, path = path, name = name}}
                                  in
                                    occ (I.BEntry (#kind e), #path e, #name e, qualified)
                                    :: List.map (fn c : I.con => occ (I.BCon, #path e, #name c,
                                                                       String.concatWith "." (#path e @ [#name c])))
                                                (#cons e)
                                  end)
                               (P.entriesOf (#body s))))
                sigs)

  (* The page an identifier is listed on: its first letter, or symbols. *)
  fun letterOf (name : string) : string =
    let
      val last = List.last (String.fields (fn c => c = #".") name)
      val c = if last = "" then #"?" else String.sub (last, 0)
    in
      if Char.isAlpha c then String.str (Char.toLower c) else "symbols"
    end

  fun lessOcc (a : occurrence, b : occurrence) : bool =
    let
      val la = String.map Char.toLower (#name a)
      val lb = String.map Char.toLower (#name b)
    in
      case String.compare (la, lb) of
        LESS => true
      | GREATER => false
      | EQUAL =>
          (case String.compare (#name a, #name b) of
             LESS => true
           | GREATER => false
           | EQUAL =>
               (case String.compare (#kind a, #kind b) of
                  LESS => true
                | GREATER => false
                | EQUAL => String.compare (#signat a, #signat b) = LESS))
    end

  fun indexPages (env : P.env, sigs : I.signatureRecord list) : file list * string list =
    let
      val occs = sort lessOcc (occurrences sigs)
      val letters = List.foldl (fn (o', acc) => let val l = letterOf (#name o') in
                                                  if List.exists (fn l' => l' = l) acc then acc else acc @ [l] end)
                               [] occs
      val ordered = sort (fn (a, b) => (a <> "symbols" andalso b = "symbols") orelse
                                       (a <> "symbols" andalso b <> "symbols" andalso a < b)) letters
      fun page l =
        let
          val path = "index/" ^ l ^ ".md"
          val mine = List.filter (fn o' => letterOf (#name o') = l) occs
          (* one line per name and kind, with every signature that has it *)
          fun groups [] = []
            | groups ((o' : occurrence) :: rest) =
                let val (same, others) = List.partition (fn p : occurrence => #name p = #name o' andalso #kind p = #kind o') rest
                in (o' :: same) :: groups others end
          fun line (g : occurrence list) =
            let val first = List.hd g
            in
              "- " ^ M.code (#name first) ^ " (" ^ #kind first ^ "): "
              ^ String.concatWith ", "
                  (List.map (fn o' : occurrence =>
                               "[" ^ #signat o' ^ "](" ^ P.href ({index = #index env, root = "../", up = #up env,
                                                                  claims = #claims env, notesOf = #notesOf env,
                                                                  ratchet = #ratchet env, topLevel = #topLevel env,
                                                                  tests = #tests env, annotations = #annotations env,
                                                                  links = #links env, anchors = #anchors env},
                                                                 path, {page = R.sigPage (#signat o'), anchor = #anchor o'},
                                                                 Source.noSpan) ^ ")") g) ^ "\n"
            end
        in
          (path,
           "# Index: " ^ (if l = "symbols" then "symbolic identifiers" else capitalised l) ^ "\n\n"
           ^ "[Overview](../README.md) &middot; "
           ^ String.concatWith " " (List.map (fn l' => if l' = l then "**" ^ l' ^ "**" else "[" ^ l' ^ "](" ^ l' ^ ".md)") ordered)
           ^ "\n\n" ^ String.concat (List.map line (groups mine))
           ^ "\n---\n\n<sub>Generated by runedoc; do not edit.</sub>\n")
        end
    in
      (List.map page ordered, ordered)
    end

  (* ---- the whole tree ---- *)
  fun components (path : string) : string list =
    List.filter (fn c => c <> "" andalso c <> ".") (String.fields (fn c => c = #"/") (P.normalise path))

  (* From the root of the output up to the directory that the paths of the
     sources are relative to. *)
  fun upFrom (out : string) : string = String.concat (List.map (fn _ => "../") (components out))

  fun overviewOf (dir : string) : I.doc =
    let
      val path = dir ^ "/overview.doc"
      val ins = TextIO.openIn path
      val text = TextIO.inputAll ins before TextIO.closeIn ins
      val span = {file = path, start = 0, stop = 0}
    in
      T.parse (fn why => DocDiag.error (span, why)) text
    end
    handle IO.Io _ => []

  (* Every anchor of a page once, and every link to a page and an anchor that
     are there. pages: the pages that exist, or NONE when only some pages were
     made and links to others cannot be judged. *)
  fun verify (env : P.env, pages : string list option) : unit =
    let
      val anchors = List.rev (!(#anchors env))
      val () =
        ignore (List.foldl (fn ((page, a, span), seen) =>
                              let val key = page ^ "#" ^ a
                              in
                                if StringMap.member (seen, key)
                                then (DocDiag.error (span, "the anchor " ^ a ^ " is on " ^ page ^
                                                           " twice: two names that differ only in case"); seen)
                                else StringMap.insert (seen, key, ())
                              end)
                           StringMap.empty anchors)
      val known = List.foldl (fn ((page, a, _), m) => StringMap.insert (m, page ^ "#" ^ a, ())) StringMap.empty anchors
      val made = List.foldl (fn ((page, _, _), m) => StringMap.insert (m, page, ())) StringMap.empty anchors
      fun exists page = case pages of SOME ps => List.exists (fn p => p = page) ps | NONE => true
    in
      List.app (fn (page, a, span) =>
                  if not (exists page) then
                    DocDiag.error (span, "a link leads to " ^ page ^ ", which is not generated")
                  else if a <> "" andalso (isSome pages orelse StringMap.member (made, page))
                          andalso not (StringMap.member (known, page ^ "#" ^ a)) then
                    DocDiag.error (span, "a link leads to " ^ page ^ "#" ^ a ^ ", which is not there")
                  else ())
               (List.rev (!(#links env)))
    end

  (* ---- every specified member has a check ---- *)
  (* For every structure that claims a signature, every value and exception
     that the signature specifies itself (what it includes is the business of
     the claim to the included signature) has a check whose label begins with
     `Structure.member/`. A structure that is another structure by name
     (`structure LargeInt = IntInf`) is checked under either name. Returns the
     number of members that have checks; the missing ones are errors. *)
  fun coverageOf (modules : I.module list, claims : DocClaims.claim list, index : R.index,
                  sites : DocTests.site list, tests : string) : int =
    let
      val scopes = List.foldl (fn (s : DocTests.site, m) => StringMap.insert (m, #scope s, ())) StringMap.empty sites
      fun structAt (ms : I.module list, names) =
        case names of
          [] => NONE
        | n :: rest =>
            (case List.find (fn I.Struct {name, ...} => name = n | _ => false) ms of
               SOME (I.Struct r) => if List.null rest then SOME r else structAt (#subs r, rest)
             | _ => NONE)
      fun aliasOf name =
        case structAt (modules, String.fields (fn c => c = #".") name) of
          SOME {rhs = I.Alias t, ...} => SOME t
        | _ => NONE
      (* the public structures that are bound to this one by name: Math is Real.Math *)
      fun aliasesOf name =
        List.mapPartial (fn I.Struct {name = n, rhs = I.Alias t, ...} => if t = name andalso isPublic n then SOME n else NONE
                          | _ => NONE) modules
      val covered = ref 0
      (* a structure that claims a signature in a comment or is ascribed it;
         not one that has it only through `structure A = B`, which is B's *)
      fun check (c : DocClaims.claim) =
        if #isFunctor c orelse #origin c = "inherited" then ()
        else
          List.app (fn e : I.entryRecord =>
                      if #kind e <> I.Val andalso #kind e <> I.Exception then ()
                      else
                        let
                          val member = String.concatWith "." (#path e @ [#name e])
                          fun has n = StringMap.member (scopes, n ^ "." ^ member)
                        in
                          if has (#name c) orelse (case aliasOf (#name c) of SOME t => has t | NONE => false)
                             orelse List.exists has (aliasesOf (#name c))
                          then covered := !covered + 1
                          else DocDiag.error (#span e, "no check labelled \"" ^ #name c ^ "." ^ member ^ "/...\" in " ^ tests
                                                       ^ " (" ^ #name c ^ " implements " ^ #signat c ^ ")")
                        end)
                   (P.entriesOf (R.bodyOf (index, #signat c)))
    in
      List.app check claims;
      !covered
    end

  (* ---- the types that are one type ---- *)
  (* names: every type of the library with the stamp of its type name and its
     arity (DocElab.typeNames). A type name that has several names is a row:
     the name of the top level first, or else the shortest. *)
  (* Why a name is a name of its type (D7, and the owner's decision of
     2026-09-21 that types are one type only where the specification has it
     so): the signature of the structure, with the `where type`s of its
     claim, says which type it is; or the top level is defined to have the
     type of that structure; or the structure is another structure by name,
     which the specification leaves to the implementation; or nothing says
     so, the specification keeps the type abstract, and the library shows
     what it is made of. *)
  datatype reason = BySignature | ByTopLevel | ByChoice | Leak

  fun typesPage (env : P.env, title : string, modules : I.module list, lib : DocElab.library,
                 names : (string * int * int) list) : string =
    let
      val page = "types.md"
      fun structAt (ms : I.module list, path) =
        case path of
          [] => NONE
        | n :: rest =>
            (case List.find (fn I.Struct {name, ...} => name = n | _ => false) ms of
               SOME (I.Struct r) => if List.null rest then SOME r else structAt (#subs r, rest)
             | _ => NONE)
      (* a structure on the way to the type is another public structure by name *)
      fun isAlias (path : string list) =
        let
          fun upTo k = k >= 1 andalso
                       ((case structAt (modules, List.take (path, k)) of
                           SOME {rhs = I.Alias t, ...} => isPublic (List.hd (String.fields (fn c => c = #".") t))
                         | _ => false)
                        orelse upTo (k - 1))
        in
          upTo (List.length path)
        end
      fun reasonOf (name : string, topLevel : string list) : reason =
        let
          val parts = String.fields (fn c => c = #".") name
          val path = List.take (parts, List.length parts - 1)
          val ty = List.last parts
          (* what the claims of the structures on the way say *)
          fun determined k =
            k >= 1 andalso
            (List.exists (fn c : DocClaims.claim =>
                            #name c = String.concatWith "." (List.take (path, k)) andalso not (#isFunctor c)
                            andalso DocElab.typeSpecOf lib (#signat c ^ (if #realisations c = "" then "" else " " ^ #realisations c),
                                                            List.drop (path, k), ty) = SOME DocElab.Determined)
                         (#claims env)
             orelse determined (k - 1))
        in
          if determined (List.length path) then BySignature
          else if isAlias path then ByChoice
          else if List.exists (fn t => t = ty) topLevel then ByTopLevel
          else Leak
        end
      (* Where a type is documented: with the signature that the structure
         claims, or one around it; the longest structure first. A type of a
         structure that no signature specifies is not the library's to show. *)
      fun target (name : string) : R.target option =
        let
          val parts = String.fields (fn c => c = #".") name
          fun from k =
            if k < 1 then NONE
            else
              let
                val structure' = String.concatWith "." (List.take (parts, k))
                val rest = List.drop (parts, k)
                val (sub, ty) = (List.take (rest, List.length rest - 1), List.last rest)
                fun first [] = NONE
                  | first ((c : DocClaims.claim) :: cs) =
                      if #name c <> structure' orelse #isFunctor c then first cs
                      else (case R.typeAt (#index env, R.sigPage (#signat c), R.bodyOf (#index env, #signat c), sub, ty) of
                              SOME t => SOME t
                            | NONE => first cs)
              in
                case first (#claims env) of SOME t => SOME t | NONE => from (k - 1)
              end
        in
          from (List.length parts - 1)
        end
      fun link n = Option.map (fn t => P.href (env, page, t, Source.noSpan)) (target n)
      fun qualified (n : string) = CharVector.exists (fn c => c = #".") n
      fun better (a : string, b : string) =
        if qualified a <> qualified b then not (qualified a)
        else String.size a < String.size b orelse (String.size a = String.size b andalso a < b)
      val names = List.filter (fn (n, _, _) => not (qualified n) orelse isSome (target n)) names
      val groups =
        List.foldl (fn ((name, stamp, arity), m) =>
                      IntMap.insert (m, stamp, case IntMap.find (m, stamp) of
                                                 SOME (a, ns) => (a, name :: ns)
                                               | NONE => (arity, [name])))
                   IntMap.empty names
      (* The name a row stands under: that of the top level, or else the type
         that nothing else determines, which is where it is defined
         (`Word8.word`, not `BinIO.elem`); the shortest of several. *)
      fun defines n = not (qualified n) orelse reasonOf (n, []) = Leak
      fun first (a : string, b : string) =
        if qualified a <> qualified b then not (qualified a)
        else if defines a <> defines b then defines a
        else better (a, b)
      val rows =
        List.mapPartial (fn (arity, ns) =>
                           case sort first ns of
                             first :: (rest as _ :: _) => SOME (arity, first, rest)
                           | _ => NONE)
                        (IntMap.listItems groups)
      val rows = sort (fn ((_, a : string, _), (_, b, _)) => String.map Char.toLower a < String.map Char.toLower b
                                                           orelse (String.map Char.toLower a = String.map Char.toLower b andalso a < b)) rows
      (* every other name of a row with its reason; the names of the top level in the row *)
      val reasoned =
        List.map (fn (arity, first, rest) =>
                    let val top = List.filter (not o qualified) (first :: rest)
                    in (arity, first, List.map (fn n => (n, if qualified n then reasonOf (n, top) else ByTopLevel)) rest) end)
                 rows
      fun count r = List.length (List.filter (fn (_, r') => r' = r) (List.concat (List.map #3 reasoned)))
      (* the types that a signature leaves abstract and that are a record, a
         tuple or the like for a program: they are one type with no other
         name, and show what they are made of all the same *)
      val made =
        List.concat
          (List.map (fn c : DocClaims.claim =>
                       if #isFunctor c orelse #origin c = "inherited" then []
                       else
                         List.mapPartial (fn (sub, ty) =>
                                            let val path = String.fields (fn ch => ch = #".") (#name c) @ sub
                                            in
                                              (* `General.unit` is the `unit` of the top level, which is defined to be one *)
                                              if DocElab.showsItsMaking lib (path, ty)
                                                 andalso not (DocElab.showsItsMaking lib ([], ty))
                                              then SOME (String.concatWith "." (path @ [ty]))
                                              else NONE
                                            end)
                                         (DocElab.abstractTypesOf lib (#signat c ^ (if #realisations c = "" then "" else " " ^ #realisations c))))
                    (#claims env))
      val made = sort (fn (a : string, b) => a < b)
                      (List.foldl (fn (n, acc) => if List.exists (fn m => m = n) acc then acc else n :: acc) [] made)
      val labels = [(BySignature, "required by the signature"), (ByTopLevel, "required of the top level"),
                    (ByChoice, "the implementation's choice"), (Leak, "abstract in the specification")]
      fun vars 0 = ""
        | vars 1 = "'a "
        | vars n = "(" ^ String.concatWith ", " (List.tabulate (n, fn i => "'" ^ String.str (Char.chr (Char.ord #"a" + i)))) ^ ") "
      fun shown arity n = case link n of
                            SOME href => "[" ^ M.code (vars arity ^ n) ^ "](" ^ href ^ ")"
                          | NONE => M.code (vars arity ^ n)
    in
      "# Types that are one type\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "Types with several names: a value of one is a value of the others, and a function on one takes\n"
      ^ "them all. They are found by elaborating the library and comparing the type names, so the table\n"
      ^ "says what is the case and not only what is meant. A type that abbreviates more than a name, such\n"
      ^ "as a reader or a record, is not listed. Every name says why it is a name of its type:\n\n"
      ^ "- **required by the signature** (" ^ Int.toString (count BySignature) ^ "): the signature of the structure, with the `where type`\n"
      ^ "  of its declaration in the specification, says which type it is, as `CharVector.vector` is `string`;\n"
      ^ "- **required of the top level** (" ^ Int.toString (count ByTopLevel) ^ "): the top level is defined to have the type of that\n"
      ^ "  structure, as `int` is `Int.int`;\n"
      ^ "- **the implementation's choice** (" ^ Int.toString (count ByChoice) ^ "): the structure is another structure by name, which the\n"
      ^ "  specification leaves open, as `Position` is `Int` here; a program that relies on it is not portable;\n"
      ^ "- **abstract in the specification** (" ^ Int.toString (count Leak) ^ "): nothing says which type it is, and the library shows\n"
      ^ "  what it is made of. A program that relies on it is not portable, and the type checker of another\n"
      ^ "  system rejects it. There should be none of these.\n\n"
      ^ M.table (["Type", "Also"],
                 List.map (fn (arity, first, rest) =>
                             [shown arity first,
                              String.concatWith "<br>"
                                (List.mapPartial (fn (r, label) =>
                                                    case List.filter (fn (_, r') => r' = r) rest of
                                                      [] => NONE
                                                    | ns => SOME ("*" ^ label ^ ":* " ^ String.concatWith ", " (List.map (shown arity o #1) ns)))
                                                 labels)])
                          reasoned)
      ^ (if List.null made then ""
         else "## Types that show what they are made of\n\n"
              ^ "The specification keeps these types abstract, and for a program they are a record, a tuple or a\n"
              ^ "function: a program can take them apart, and is not portable when it does. There should be none\n"
              ^ "of these either (" ^ Int.toString (List.length made) ^ ").\n\n"
              ^ String.concatWith ", " (List.map (shown 0) made) ^ "\n\n")
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  (* ---- the notes ---- *)
  fun dedupNotes (notes : DocNotes.note list) : DocNotes.note list =
    List.foldl (fn (n, acc) =>
                  (* a declaration of several names has its note once for each: keep one *)
                  if List.exists (fn m : DocNotes.note => #id m = #id n andalso #kind m = #kind n andalso #structure' m = #structure' n
                                                          andalso #member m <> #member n
                                                          andalso #start (#span m) = #start (#span n) andalso #file m = #file n) acc
                  then acc else acc @ [n])
               [] notes

  fun readingsPage (env : P.env, title : string, notes : DocNotes.note list, labels : DocNotes.labels option) : string =
    let
      val page = "readings.md"
      fun link c = case R.resolve (#index env, "", [], []) c of
                     R.Target t => SOME (P.href (env, page, t, Source.noSpan))
                   | _ => NONE
      fun whereOf (n : DocNotes.note) =
        let
          val target =
            if #signat n = "" then NONE
            else if #member n = "" then SOME {page = R.sigPage (#signat n), anchor = ""}
            else
              let val names = String.fields (fn c => c = #".") (#member n)
              in
                R.memberAt (#index env, R.sigPage (#signat n), R.bodyOf (#index env, #signat n),
                            List.take (names, List.length names - 1), List.last names)
              end
          val shown = (if #signat n = "" then "" else #signat n) ^ (if #member n = "" then "" else "." ^ #member n)
        in
          (case target of
             SOME t => "[" ^ M.code shown ^ "](" ^ P.href (env, page, t, #span n) ^ ")"
           | NONE => if shown = "" then "" else M.code shown)
          ^ (if #structure' n = "" then "" else (if shown = "" then "" else ", ") ^ "in " ^ M.code (#structure' n))
        end
      (* the text without the id it begins with *)
      fun textOf (n : DocNotes.note) =
        case #text n of
          T.Code _ :: rest => M.cell link rest
        | is => M.cell link is
      fun pinned (n : DocNotes.note) =
        case labels of
          SOME ls => if DocNotes.isPinned ls n then "" else " *(no check pins it)*"
        | NONE => ""
      fun section (kind, heading, intro) =
        case List.filter (fn n : DocNotes.note => #kind n = kind) notes of
          [] => ""
        | ns =>
            "## " ^ heading ^ "\n\n" ^ intro ^ "\n\n"
            ^ String.concat (List.map (fn n : DocNotes.note =>
                                         "- " ^ M.code (#id n) ^ (if #differs n then " (the suite differs)" else "")
                                         ^ " &mdash; " ^ whereOf n ^ textOf n ^ pinned n ^ "\n") ns)
            ^ "\n"
    in
      "# How the library reads its specification\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "The notes of the documentation, from the comments of the library. The name of a note is the label of\n"
      ^ "the check of the test suite that pins it, where there is one.\n\n"
      ^ section ("Reading", "Readings", "Where the text is silent, ambiguous or contradicts itself, and what it is taken to say.")
      ^ section ("Erratum", "Errata", "Where the specification is wrong.")
      ^ section ("Deviation", "Deviations", "Where the library departs from the specification.")
      ^ section ("Implementation", "Choices of the implementation", "What the specification leaves open, and what the library does.")
      ^ section ("Limitation", "Limitations", "What is missing or only partly there.")
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  (* ---- the ratchet ---- *)
  (* DOCUMENTED, in the directory of the library, lists the signatures that are
     documented in full, one on a line (# begins a comment). For them what is
     otherwise only counted in coverage.md is an error: an entry without
     documentation, a function without a usage head, a first paragraph that is
     too long for a summary, a reference that leads nowhere. So what is done
     stays done. *)
  val summaryLimit = 160

  fun ratchetOf (dir : string) : string list =
    let
      val ins = TextIO.openIn (dir ^ "/DOCUMENTED")
      val text = TextIO.inputAll ins before TextIO.closeIn ins
    in
      List.filter (fn l => l <> "" andalso not (String.isPrefix "#" l))
                  (List.map (fn l => String.concat (String.tokens Char.isSpace l)) (String.fields (fn c => c = #"\n") text))
    end
    handle IO.Io _ => []

  fun checkRatchet (dir : string, sigs : I.signatureRecord list, ratchet : string list) : unit =
    (List.app (fn r =>
                 if List.exists (fn s : I.signatureRecord => #name s = r) sigs then ()
                 else DocDiag.error ({file = dir ^ "/DOCUMENTED", start = 0, stop = 0}, r ^ " is no signature of the library"))
              ratchet;
     List.app (fn s : I.signatureRecord =>
                 if not (List.exists (fn r => r = #name s) ratchet) then ()
                 else
                   (if List.null (#doc s) then DocDiag.error (#span s, "signature " ^ #name s ^ " has no comment, and DOCUMENTED lists it") else ();
                    List.app (fn e : I.entryRecord =>
                                let
                                  val what = I.kindName (#kind e) ^ " " ^ String.concatWith "." (#path e @ [#name e])
                                  val summary = T.plain (P.summaryOf (#doc e))
                                in
                                  if not (P.isDocumented e) then
                                    DocDiag.error (#span e, what ^ " is not documented, and DOCUMENTED lists " ^ #name s)
                                  else if P.isFunction e andalso List.null (#heads e) then
                                    DocDiag.error (#span e, what ^ " is a function whose description shows no usage, such as `" ^ #name e ^ " x`")
                                  else if String.size summary > summaryLimit then
                                    DocDiag.error (#span e, "the first paragraph of " ^ what ^ " has " ^ Int.toString (String.size summary)
                                                            ^ " characters; it is the summary, of at most " ^ Int.toString summaryLimit)
                                  else ()
                                end)
                             (P.entriesOf (#body s))))
              sigs)

  (* The structure that the examples of a signature are read in. *)
  fun exampleStructureOf (claims : DocClaims.claim list, sigStatus : string -> string) : string -> string option =
    DocExamples.structureOf (claims, fn c : DocClaims.claim => case #status c of SOME st => st | NONE => sigStatus (#signat c))

  fun build {dir : string, prelude : string option, title : string, out : string, tests : string option,
             annotations : string option} : file list =
    let
      val modules = load dir
      val sigs = sort (fn (a : I.signatureRecord, b : I.signatureRecord) => String.compare (#name a, #name b) = LESS) (signaturesOf modules)
      val ratchet = ratchetOf dir
      val sites = case tests of SOME t => DocTests.suite t | NONE => []
      val annotated = Option.map DocAnnot.load annotations
      val (claims, index, env) = envOf (modules, upFrom out, ratchet, sites, annotated)
      val () = DocClaims.checkNames (#signatures index) claims
      val () = checkRatchet (dir, sigs, ratchet)
      (* with a suite: every specified member of a claimed structure has a check *)
      val () = case tests of SOME t => ignore (coverageOf (modules, claims, index, sites, t)) | NONE => ()
      val notes = dedupNotes (DocNotes.ofModules (isPublic, fn name => StringMap.find (#structures index, name)) modules)
      val labels = case tests of SOME _ => SOME (DocNotes.labelsOf sites) | NONE => NONE
      val () = DocNotes.checkIds notes
      val () = case labels of SOME ls => DocNotes.checkPins ls notes | NONE => ()
      fun sigStatus s = case StringMap.find (#signatures index, s) of
                          SOME (I.Signature {doc, ...}) => P.statusOf doc
                        | _ => "required"
      val exampleStructure = exampleStructureOf (claims, sigStatus)
      (* the claims that name a signature of the library, checked by the compiler *)
      val elaborated = DocElab.library (dir, prelude)
      val () =
        case elaborated of
          SOME lib =>
            (List.app (fn c : DocClaims.claim =>
                         if StringMap.member (#signatures index, #signat c) then DocElab.checkClaim lib c else ())
                      claims;
             (* the usage heads of the values at the top of a signature, against their elaborated types *)
             List.app (fn s : I.signatureRecord =>
                         List.app (fn e : I.entryRecord =>
                                     if #kind e = I.Val andalso List.null (#path e)
                                     then List.app (fn h => DocElab.checkHead (#name s, #name e, h, #span e)) (#heads e)
                                     else ())
                                  (P.entriesOf (#body s)))
                      sigs;
             (* the examples that are equations, under the structure they are read in *)
             List.app (fn s : I.signatureRecord =>
                         List.app (fn e => DocElab.checkExample lib (#code e, DocExamples.expression (exampleStructure (#name s), e), #span e))
                                  (DocExamples.ofSignature s))
                      sigs)
        | NONE => ()
      val functors = List.mapPartial (fn I.Functor f => if isPublic (#name f) then SOME f else NONE | _ => NONE) modules
      val sigPages = List.map (fn s : I.signatureRecord => (R.sigPage (#name s), P.signaturePage (env "../", title) s)) sigs
      val funPages = List.map (fn {name, file, span, doc, param, result, ...} =>
                                 (R.funPage name, functorPage (env "../", title) (name, file, span, doc, param, result)))
                              functors
      val (indexFiles, letters) = indexPages (env "", sigs)
      val files =
        ("README.md", readme (env "", title, overviewOf dir, sigs, List.map (fn f => (#name f, #doc f)) functors, letters,
                              isSome elaborated))
        :: ("conventions.md", conventions (Option.map (fn a : DocAnnot.file => (#title a, #intro a)) annotated))
        :: ("coverage.md", coverage (sigs, case labels of
                                                  SOME ls => List.filter (fn n : DocNotes.note =>
                                                                            (#kind n = "Deviation" orelse #kind n = "Limitation")
                                                                            andalso not (DocNotes.isPinned ls n)) notes
                                                | NONE => []))
        :: ("structures.md", structuresPage (env "", title, modules, sigStatus, Option.map DocElab.namesOf elaborated,
                                             not (List.null ratchet)))
        :: ("top-level.md", topLevelPage (env "", title, modules))
        :: ("exceptions.md", exceptionsPage (env "", title, sigs))
        :: ("readings.md", readingsPage (env "", title, notes, labels))
        :: ("notes.tsv", DocNotes.tsv labels notes)
        :: ("claims.tsv", DocClaims.tsv (sort (fn (a : DocClaims.claim, b : DocClaims.claim) =>
                                                case String.compare (#name a, #name b) of
                                                  LESS => true | GREATER => false | EQUAL => #signat a < #signat b) claims,
                                         sigStatus))
        :: sigPages @ funPages @ indexFiles
        (* what only elaboration knows *)
        @ (case elaborated of
             SOME lib => [("types.md", typesPage (env "", title, modules, lib, DocElab.typeNames (lib, isPublic)))]
           | NONE => [])
      val () = verify (env "", SOME (List.map #1 files))
      (* file names differ in more than case, for the file systems that ignore it *)
      val () =
        ignore (List.foldl (fn ((path, _), seen) =>
                              let val key = String.map Char.toLower path
                              in
                                if StringMap.member (seen, key)
                                then (DocDiag.error (Source.noSpan, "two generated files differ only in case: " ^ path); seen)
                                else StringMap.insert (seen, key, ())
                              end)
                           StringMap.empty files)
      val () =
        List.app (fn (path, text) =>
                    if String.size text > pageLimit then
                      DocDiag.error (Source.noSpan, path ^ " has " ^ Int.toString (String.size text) ^
                                                    " bytes; GitHub renders pages up to about " ^ Int.toString pageLimit)
                    else ()) files
    in
      files
    end

  (* The programs that try the examples of the signatures, one for each
     signature that has an example that is an equation. *)
  fun examples {dir : string} : file list =
    let
      val modules = load dir
      val (claims, index, _) = envOf (modules, "", [], [], NONE)
      fun sigStatus s = case StringMap.find (#signatures index, s) of
                          SOME (I.Signature {doc, ...}) => P.statusOf doc
                        | _ => "required"
      val structureOf = exampleStructureOf (claims, sigStatus)
    in
      List.mapPartial (fn s : I.signatureRecord =>
                         case DocExamples.ofSignature s of
                           [] => NONE
                         | es => SOME (#name s ^ ".sml", DocExamples.program (#name s, P.normalise (#file s), structureOf (#name s), es)))
                      (sort (fn (a : I.signatureRecord, b : I.signatureRecord) => #name a < #name b) (signaturesOf modules))
    end

  fun checkCoverage {dir : string, tests : string} : int =
    let
      val modules = load dir
      val (claims, index, _) = envOf (modules, "", [], [], NONE)
    in
      coverageOf (modules, claims, index, DocTests.suite tests, tests)
    end

  (* ---- on disk ---- *)
  fun readFile (path : string) : string option =
    let val ins = TextIO.openIn path
    in SOME (TextIO.inputAll ins before TextIO.closeIn ins) end
    handle IO.Io _ => NONE

  fun isDir (path : string) : bool = OS.FileSys.isDir path handle OS.SysErr _ => false

  fun makeDirs (path : string) : unit =
    ignore (List.foldl (fn (c, prefix) =>
                          let val p = if prefix = "" then c else prefix ^ "/" ^ c
                          in (if isDir p then () else OS.FileSys.mkDir p); p end)
                       (if String.isPrefix "/" path then "/" else "") (components path))

  (* The generated files that are in a directory: .md and .tsv, below out. *)
  fun existing (out : string) : string list =
    let
      fun walk (rel : string) : string list =
        let
          val dir = if rel = "" then out else out ^ "/" ^ rel
          val d = OS.FileSys.openDir dir
          fun entries acc = case OS.FileSys.readDir d of SOME n => entries (n :: acc) | NONE => (OS.FileSys.closeDir d; acc)
          val names = sort (fn (a : string, b) => a < b) (entries [])
        in
          List.concat (List.map (fn n =>
                                   let val r = if rel = "" then n else rel ^ "/" ^ n
                                   in
                                     if isDir (out ^ "/" ^ r) then walk r
                                     else if String.isSuffix ".md" n orelse String.isSuffix ".tsv" n orelse String.isSuffix ".sml" n then [r] else []
                                   end) names)
        end
    in
      if isDir out then walk "" else []
    end

  fun stale (out : string, files : file list) : string list =
    List.filter (fn p => not (List.exists (fn (q, _) => q = p) files)) (existing out)

  fun write (out : string, files : file list) : unit =
    (List.app (fn (path, text) =>
                 let
                   val full = out ^ "/" ^ path
                   val dir = case List.rev (String.fields (fn c => c = #"/") full) of
                               _ :: rest => String.concatWith "/" (List.rev rest)
                             | [] => out
                 in
                   makeDirs dir;
                   if readFile full = SOME text then ()
                   else let val outs = TextIO.openOut full in TextIO.output (outs, text); TextIO.closeOut outs end
                 end) files;
     List.app (fn p => OS.FileSys.remove (out ^ "/" ^ p)) (stale (out, files)))

  (* What differs between the tree on disk and what would be generated. *)
  fun check (out : string, files : file list) : string list =
    List.mapPartial (fn (path, text) =>
                       case readFile (out ^ "/" ^ path) of
                         NONE => SOME (out ^ "/" ^ path ^ " is missing")
                       | SOME t => if t = text then NONE else SOME (out ^ "/" ^ path ^ " is out of date")) files
    @ List.map (fn p => out ^ "/" ^ p ^ " is no longer generated") (stale (out, files))
end

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
  (* The modules of the files of the MANIFEST, in its order. *)
  fun load (dir : string) : I.module list =
    List.concat (List.map (fn e : BasisManifest.entry => DocExtract.file (dir ^ "/" ^ #file e))
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
  fun envOf (modules : I.module list, out : string) =
    let
      val claims = DocClaims.ofModules isPublic modules
      val index = R.indexOf (modules, claims, isPublic)
      val links = ref []
      val anchors = ref []
    in
      (claims, index,
       fn root => {index = index, root = root, up = out, claims = claims, notesOf = notesOf modules,
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

  fun readme (env : P.env, title : string, overview : I.doc, sigs : I.signatureRecord list,
              functors : (string * I.doc) list, letters : string list) : string =
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
      ^ "[How to read these pages](conventions.md) &middot; [structures and what they implement](structures.md)"
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

  fun coverage (sigs : I.signatureRecord list) : string =
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
      ^ "---\n\n<sub>Generated by runedoc; do not edit.</sub>\n"
    end

  fun conventions () : string =
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
    ^ "  **Example**, **Complexity** and **See also** are what they say.\n"
    ^ "- A datatype has a table of its constructors, a record one of its fields.\n"
    ^ "- A quoted block is a note on how the library reads its specification: a **Reading** of text that is\n"
    ^ "  silent, ambiguous or contradictory, an **Erratum** of the specification, a **Deviation** of the\n"
    ^ "  library from it, a choice the specification leaves to the **Implementation**, a **Limitation**.\n"
    ^ "  The identifier after the word names the note, and the check of the test suite that pins it\n"
    ^ "  when there is one.\n\n"
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

  fun structuresPage (env : P.env, title : string, modules : I.module list, sigStatus : string -> string) : string =
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
         "[" ^ M.escape (P.normalise (#file c)) ^ "](" ^ #up env ^ P.normalise (#file c) ^ ")"]
      (* what a written-out structure declares beyond the signatures it claims *)
      fun extras (c : DocClaims.claim) =
        case structAt (modules, String.fields (fn ch => ch = #".") (#name c)) of
          SOME {members = SOME ms, ...} =>
            let
              val mine = List.filter (fn c' : DocClaims.claim => #name c' = #name c) claims
              val spec = List.concat (List.map (fn c' => specified (#index env, #signat c', [#signat c'])) mine)
              val beyond = List.filter (fn m => not (List.exists (fn s => s = m) spec)) ms
              fun distinct xs = List.foldl (fn (x, acc) => if List.exists (fn y => y = x) acc then acc else acc @ [x]) [] xs
            in
              distinct beyond
            end
        | _ => []
      val firstClaims = List.foldl (fn (c : DocClaims.claim, acc) =>
                                      if List.exists (fn c' : DocClaims.claim => #name c' = #name c) acc then acc else acc @ [c])
                                   [] claims
      val beyondRows = List.mapPartial (fn c => case extras c of [] => NONE
                                                               | ms => SOME [M.code (#name c), String.concatWith ", " (List.map M.code ms)])
                                       firstClaims
    in
      "# Structures and what they implement\n\n"
      ^ "[" ^ M.escape title ^ "](README.md)\n\n"
      ^ "Every public structure of the library that says which signature it implements. A structure is\n"
      ^ "documented on the page of its signature. `:>` means that the source seals the structure with the\n"
      ^ "signature; `:` that it matches it, which the test suite checks.\n\n"
      ^ M.table (["Structure", "Signature", "Realisations", "Status", "", "Source"], List.map row claims)
      ^ (if List.null beyondRows then ""
         else "## Names beyond the signature\n\n"
              ^ "What the body of a structure declares and its signatures do not specify. Most structures are not\n"
              ^ "sealed, so these names are visible; a program that uses them is not portable.\n\n"
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
                  ["Source", "[" ^ M.escape (P.normalise file) ^ "](" ^ #root env ^ #up env ^ P.normalise file ^ ")"]])
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

  fun build {dir : string, title : string, out : string} : file list =
    let
      val modules = load dir
      val sigs = sort (fn (a : I.signatureRecord, b : I.signatureRecord) => String.compare (#name a, #name b) = LESS) (signaturesOf modules)
      val (claims, index, env) = envOf (modules, upFrom out)
      val () = DocClaims.checkNames (#signatures index) claims
      fun sigStatus s = case StringMap.find (#signatures index, s) of
                          SOME (I.Signature {doc, ...}) => P.statusOf doc
                        | _ => "required"
      val functors = List.mapPartial (fn I.Functor f => if isPublic (#name f) then SOME f else NONE | _ => NONE) modules
      val sigPages = List.map (fn s : I.signatureRecord => (R.sigPage (#name s), P.signaturePage (env "../", title) s)) sigs
      val funPages = List.map (fn {name, file, span, doc, param, result, ...} =>
                                 (R.funPage name, functorPage (env "../", title) (name, file, span, doc, param, result)))
                              functors
      val (indexFiles, letters) = indexPages (env "", sigs)
      val files =
        ("README.md", readme (env "", title, overviewOf dir, sigs, List.map (fn f => (#name f, #doc f)) functors, letters))
        :: ("conventions.md", conventions ())
        :: ("coverage.md", coverage sigs)
        :: ("structures.md", structuresPage (env "", title, modules, sigStatus))
        :: ("claims.tsv", DocClaims.tsv (sort (fn (a : DocClaims.claim, b : DocClaims.claim) =>
                                                case String.compare (#name a, #name b) of
                                                  LESS => true | GREATER => false | EQUAL => #signat a < #signat b) claims,
                                         sigStatus))
        :: sigPages @ funPages @ indexFiles
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
                                     else if String.isSuffix ".md" n orelse String.isSuffix ".tsv" n then [r] else []
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

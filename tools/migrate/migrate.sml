(* The migrator of build files (docs/build.md, Migrating a tree; the
   build-system roadmap's D15, from E28's prototype): from a tree's build
   files as they are to the library model. It reads what it needs with the
   compiler's own readers -- CompilerProject for build files, the parser and
   Deps for sources, LibraryIndex for the Basis Library and for what a file
   claims -- and lists nothing by hand.

   Of each library with no header, not kept:
     a header: `exports`, the names of the library that a client uses -- a
     source outside it, or in a library nested in it, of the tree or of a
     tree that --clients names -- with each signature of the library that
     those ascribe (the claim rule, D8); and `requires`, what it was written
     on, with each library it uses a name of that it reached only through
     another, since a header's requires are not transitive.
   Of each header it wrote before, which says so in a comment, the same
   again from the sources as they are, so that a boundary that a merge
   brought into a branch hides nothing a client of the branch uses (D15's
   trap). A header a person wrote it leaves as it is.
   Of each other build file, not kept:
     the libraries whose every file it lists, which it names in `libraries`
     instead, and each library its own units use a name of that its scope
     would not show, since a library with a header is not transitive.
   What it cannot settle it reports and leaves: a part of a library listed,
   a build file of a library used from outside it, but by a build the
   library names a friend; a library whose sources it cannot read, or that
   declares a value or a fixity at its top level, which a header cannot
   export; and a kept build that would need a library named. A second run
   changes nothing. *)
structure Migrate =
struct
  structure P = CompilerProject
  structure B = BasisManifest
  structure BF = BuildFile

  exception Usage of string

  (* ---- small things ---- *)
  fun readText (path : string) : string =
    let val i = TextIO.openIn path in TextIO.inputAll i before TextIO.closeIn i end
  fun writeText (path : string, text : string) : unit =
    let val o' = TextIO.openOut path in TextIO.output (o', text); TextIO.closeOut o' end
  fun member x xs = List.exists (fn y => y = x) xs
  fun unique xs = List.foldl (fn (x, acc) => if member x acc then acc else acc @ [x]) [] xs
  fun under (dir : string) (path : string) : bool = String.isPrefix (dir ^ "/") path
  fun isSource p = List.exists (fn e => String.isSuffix e p) [".sml", ".sig", ".fun"]
  fun findSub (s : string, text : string) : int option =
    let val (prefix, at) = Substring.position s (Substring.full text)
    in if Substring.isEmpty at then NONE else SOME (Substring.size prefix) end
  fun lines (text : string) : string list = List.filter (fn l => l <> "") (String.tokens (fn c => c = #"\n") text)
  val kinds = ["structure", "signature", "functor", "type"]
  fun kindRank k = case k of "structure" => 0 | "signature" => 1 | "functor" => 2 | "type" => 3 | _ => 4
  fun sortNames (ns : (string * string) list) : (string * string) list =
    let
      fun less ((k, n), (k', n')) = kindRank k < kindRank k' orelse (kindRank k = kindRank k' andalso n < n')
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if less (x, y) then x :: y :: ys else y :: insert (x, ys)
    in List.foldl insert [] (unique ns) end
  fun sortStrings (xs : string list) : string list =
    let fun insert (x, []) = [x]
          | insert (x, y :: ys) = if x < y then x :: y :: ys else y :: insert (x, ys)
    in List.foldl insert [] (unique xs) end

  (* ---- what a source is to the migrator ----
     what it declares at its top level and uses, by kind and name (Deps); the
     values it binds there; what it claims (LibraryIndex.claimsOf); whether
     it adds a fixity at its top level. A file the parser cannot read alone
     -- it needs a fixity another file gives -- is read for its tokens: each
     identifier and each long name's structure, of any kind, which can only
     keep more of a library public *)
  type facts = {parsed : bool, declares : (string * string) list, uses : (string * string) list,
                values : string list, claims : (string * string * string) list, fixity : bool,
                parameters : (string * string) list, comments : string list}
  val unread : facts = {parsed = false, declares = [], uses = [], values = [], claims = [], fixity = false,
                        parameters = [], comments = []}
  (* the signatures runedoc's comments claim, `Implements: SIG`, and a
     functor's parameter's signature: neither is the claim rule's, but
     runedoc documents both, and a spare signature costs nothing (E28) *)
  fun commentClaims (text : string) : string list =
    let
      val key = "Implements:"
      fun name s = let val s = Substring.dropl (fn c => Char.isSpace c orelse c = #"`") s
                       val n = Substring.string (Substring.takel (fn c => Char.isUpper c orelse Char.isDigit c orelse c = #"_") s)
                   in if n <> "" andalso Char.isUpper (String.sub (n, 0)) then [n] else [] end
      fun go s =
        let val (_, at) = Substring.position key s
        in if Substring.isEmpty at then [] else let val rest = Substring.triml (size key) at in name rest @ go rest end end
    in go (Substring.full text) end
  fun parametersOf (prog : Ast.program) : (string * string) list =
    let
      fun named (Ast.SigId (n, _, _)) = SOME n
        | named (Ast.SigWhere (g, _, _, _)) = named g
        | named (Ast.SigSig _) = NONE
      fun top d =
        case d of
          Ast.DFunctor (bs, _, _) => List.mapPartial (fn {name, paramSig, ...} : Ast.funbind =>
                                                         Option.map (fn s => (name, s)) (named paramSig)) bs
        | Ast.DLocal (_, b, _, _) => List.concat (List.map top b)
        | _ => []
    in List.concat (List.map top prog) end
  fun word (k, n) = (Deps.kindName k, n)
  fun tokenUses (toks : Lexer.item vector) : (string * string) list =
    Vector.foldr (fn ((Token.LONGID (s :: _, _), _), acc) => ("", s) :: acc
                   | ((Token.ID n, _), acc) => ("", n) :: acc
                   | (_, acc) => acc) [] toks
  fun readFacts (path : string) : facts =
    let
      val file = Source.readFile (Source.Unicode Source.Utf8, path)
      val toks = Lexer.tokenize file
    in
      (let
         val (prog, fx) = Parser.parseTokensWith (toks, Fixity.initial)
         val d = Deps.analyse (path, prog)
       in
         {parsed = true, declares = List.map word (#declares d), uses = List.map word (#uses d), values = #values d,
          claims = LibraryIndex.claimsOf prog, fixity = length (#list fx) > length (#list Fixity.initial),
          parameters = parametersOf prog, comments = commentClaims (#text file)}
       end
       handle _ => {parsed = false, declares = [], uses = tokenUses toks, values = [], claims = [], fixity = false,
                    parameters = [], comments = []})
    end
    handle _ => unread
  val known = ref (StringMap.empty : facts StringMap.map)
  fun factsOf (path : string) : facts =
    case StringMap.find (!known, path) of
      SOME f => f
    | NONE => let val f = readFacts path in known := StringMap.insert (!known, path, f); f end

  (* ---- the tree ---- *)
  type options = {write : bool, report : string option, keep : string list, clients : string list,
                  ignore : string list, lib : string, list : string}

  (* the files under a directory, by their paths from it *)
  fun walk (top : string) : string list =
    let
      fun go (rel : string) : string list =
        let
          val path = if rel = "" then top else top ^ "/" ^ rel
          val d = OS.FileSys.openDir path
          fun entries acc = case OS.FileSys.readDir d of
                              NONE => List.rev acc
                            | SOME e => entries (e :: acc)
          val es = entries [] before OS.FileSys.closeDir d
        in
          List.concat (List.map (fn e =>
            let val r = if rel = "" then e else rel ^ "/" ^ e
            in if String.isPrefix "." e then []
               else if OS.FileSys.isDir (top ^ "/" ^ r) then go r
               else [r] end) es)
        end
    in go "" end

  (* a library: its place under lib, its directory and build file, what its
     build file says, and its units, each a path from the tree's top with its
     annotations; NONE where its build file cannot be planned *)
  type library = {name : string, dir : string, build : string, plan : P.plan option, units : (string * string list) list}

  (* a path as the tree's list has it: from the tree's top, with no . or ..,
     where a path variable made it absolute *)
  val top = OS.FileSys.getDir ()
  fun tidy (p : string) : string =
    P.pathKey false (if String.isPrefix (top ^ "/") p then String.extract (p, size top + 1, NONE) else p)
  fun tidySteps (steps : P.step list) : P.step list =
    List.map (fn P.SUnit (p, anns) => P.SUnit (tidy p, anns)
               | P.SLibrary (es, ss) => P.SLibrary (es, tidySteps ss)
               | P.SUse (k, ss) => P.SUse (k, tidySteps ss)
               | P.SImplements (n, ss) => P.SImplements (n, tidySteps ss)) steps
  fun planOf (file : string) : P.plan option =
    let
      val {steps, libraries, header, inputs, inline, inlineValues, references, basis, view, generates, preprocessors} =
        P.planWith {file = file, windows = false, hosts = false, readBuild = fn p => {text = readText p, revision = ""}}
    in
      SOME {steps = tidySteps steps, libraries = libraries, header = header, inputs = inputs, inline = inline,
            inlineValues = inlineValues, references = List.map (fn (b, t) => (tidy b, tidy t)) references, basis = basis,
            view = view, generates = generates, preprocessors = preprocessors}
    end
    handle _ => NONE

  (* ---- headers, as text ---- *)
  (* what marks a header the migrator wrote, which it writes again; a person
     who takes a boundary over deletes the line *)
  val mark = "(* exports: what the library's clients use (tools/migrate; docs/build.md, Migrating a tree) *)"
  fun exportsText (names : (string * string) list) : string =
    let
      val items = List.map (fn (k, n) => k ^ " " ^ n) (sortNames names)
      fun fill ([], line, acc) = List.rev (line :: acc)
        | fill (item :: rest, line, acc) =
            if line = "" then fill (rest, item, acc)
            else if size line + size item + 2 > 100 then fill (rest, item, (line ^ ",") :: acc)
            else fill (rest, line ^ ", " ^ item, acc)
    in "exports (" ^ String.concatWith "\n         " (fill (items, "", [])) ^ ")" end
  fun headerText (requires : string list, exports : (string * string) list) : string =
    (if List.null requires then "" else "requires " ^ String.concatWith " " requires ^ " end\n")
    ^ mark ^ "\n" ^ exportsText exports ^ "\n"

  (* a word of an import as a build file writes it: NAME, or NAME (KIND FROM
     as TO, ...) *)
  fun importText (word : string) : string =
    let val {name, view, renames} = B.importOf word
        val head = name ^ (case view of NONE => "" | SOME v => "#" ^ v)
    in
      case renames of
        [] => head
      | rs => head ^ " (" ^ String.concatWith ", " (List.map B.renameText rs) ^ ")"
    end
  fun nameOf (word : string) : string = #name (B.importOf word)

  (* the build file's words, with where each is *)
  fun lexemes (path, text) = BF.lexemes (path, text, false)
  fun isWord w (l : BF.lexeme) = case #word l of BF.W s => s = w | BF.S _ => false

  (* the text without [start, stop), and the blank line it leaves *)
  fun cut (text : string, start : int, stop : int) : string =
    let
      val n = size text
      fun lineStart i = if i > 0 andalso String.sub (text, i - 1) <> #"\n" then lineStart (i - 1) else i
      fun lineStop i = if i < n andalso String.sub (text, i) <> #"\n" then lineStop (i + 1) else i
      val a = lineStart start
      val b = lineStop stop
      val blank = CharVector.all Char.isSpace (String.substring (text, a, start - a))
                  andalso CharVector.all Char.isSpace (String.substring (text, stop, b - stop))
    in
      if blank then String.substring (text, 0, a) ^ String.extract (text, Int.min (n, b + 1), NONE)
      else String.substring (text, 0, start) ^ String.extract (text, stop, NONE)
    end
  fun splice (text : string, at : int, piece : string) : string =
    String.substring (text, 0, at) ^ piece ^ String.extract (text, at, NONE)

  (* the extent of a part that begins with word and ends at the first end,
     or with the parenthesis that closes it *)
  fun partExtent (ls : BF.lexeme list, w : string, closer : string) : (int * int) option =
    let
      fun find [] = NONE
        | find (l :: rest) = if isWord w l then close (#start l, rest) else find rest
      and close (start, []) = NONE
        | close (start, l :: rest) = if isWord closer l then SOME (start, #stop l) else close (start, rest)
    in find ls end

  (* ---- the migration ---- *)
  type change = {path : string, text : string}

  fun run (opts : options) : int =
    let
      val report = ref [] : (string * string) list ref
      fun note (category, line) = report := (category, line) :: !report
      val lib = #lib opts
      val listed = lines (if #list opts = "-" then TextIO.inputAll TextIO.stdIn else readText (#list opts))
      val ignored = fn p => List.exists (fn pre => String.isPrefix pre p) (#ignore opts)
      val builds = List.filter (fn p => String.isSuffix ".build" p) listed
      val kept = fn p => member p (#keep opts)
      val generated = fn p => String.isSubstring "/generated/" p
      val sources = List.filter (fn p => isSource p andalso not (ignored p)) listed
      (* the libraries, the deepest owning a path *)
      val libraryBuilds = List.filter (fn p => under lib p andalso OS.Path.file p = "library.build") builds
      val dirs = List.map OS.Path.dir libraryBuilds
      fun libraryOf (path : string) : string option =
        List.foldl (fn (d, found) => if under d path andalso (case found of NONE => true | SOME f => size d > size f)
                                     then SOME d else found) NONE dirs
      val basisDir = lib ^ "/basis"
      fun placeOf dir = String.extract (dir, size lib + 1, NONE)
      val libraries : library list =
        List.map (fn build =>
                    let val dir = OS.Path.dir build
                        val plan = planOf build
                    in {name = placeOf dir, dir = dir, build = build, plan = plan,
                        units = case plan of SOME p => P.units (#steps p) | NONE => []} end) libraryBuilds
      fun libraryNamed (n : string) : library option = List.find (fn l => #name l = nameOf n) libraries
      fun libraryAt (dir : string) : library option = List.find (fn l => #dir l = dir) libraries
      fun requiresOf (l : library) : string list = case #plan l of SOME p => #libraries p | NONE => []
      fun headerOf (l : library) : BF.header option = case #plan l of SOME p => #header p | NONE => NONE
      fun exportsOf (l : library) : (string * string) list option =
        case #plan l of
          SOME {header = SOME _, steps = [P.SLibrary (es, _)], ...} =>
            SOME (List.map (fn (k, n) => (case k of BF.Str => "structure" | BF.Sig => "signature" | BF.Fun => "functor"
                                                 | BF.Ty => "type" | BF.Fix => "fixity", n)) es)
        | SOME {header = SOME _, ...} => SOME []
        | _ => NONE
      (* the Basis Library's names, from its index: never a library's to
         give a program *)
      val basisNames =
        (List.foldl (fn (e, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (B.public e)) StringMap.empty
                    (LibraryIndex.entries {root = lib, dir = basisDir}))
        handle _ => StringMap.empty
      fun inBasis n = StringMap.member (basisNames, n)
      fun final (anns : string list) = P.classOf anns = "final"
      (* what a library's files declare that a client may name: not its final
         files', which come after every program *)
      fun declaredBy (l : library) : (string * string) list =
        unique (List.concat (List.map (fn (p, anns) => if final anns then [] else #declares (factsOf p)) (#units l)))
      fun usedBy (l : library) : (string * string) list =
        let val own = declaredBy l
        in List.filter (fn (_, n) => not (List.exists (fn (_, m) => m = n) own) andalso not (inBasis n))
                       (unique (List.concat (List.map (fn (p, _) => #uses (factsOf p)) (#units l)))) end

      (* ---- the libraries, those each requires before it ---- *)
      fun ordered () : library list =
        let
          fun visit (l : library, (seen, acc)) =
            if member (#dir l) seen then (seen, acc)
            else
              let val (seen', acc') = List.foldl (fn (w, s) => case libraryNamed w of SOME m => visit (m, s) | NONE => s)
                                                 (#dir l :: seen, acc) (requiresOf l)
              in (seen', acc' @ [l]) end
        in #2 (List.foldl visit ([], []) libraries) end
      (* what each library's clients see of it once this run is done: its
         exports where it will have a header, else all it declares *)
      val decided = ref (StringMap.empty : ((string * string) list option * string list) StringMap.map)
      fun publicOf (l : library) : (string * string) list =
        case StringMap.find (!decided, #dir l) of
          SOME (SOME es, _) => es
        | SOME (NONE, _) => declaredBy l
        | NONE => (case exportsOf l of SOME es => es | NONE => declaredBy l)
      fun requiresNow (l : library) : string list =
        case StringMap.find (!decided, #dir l) of SOME (_, rs) => rs | NONE => requiresOf l
      fun closureOf (words : string list) : library list =
        let
          fun go ([], seen) = seen
            | go (w :: rest, seen) =
                case libraryNamed w of
                  NONE => go (rest, seen)
                | SOME l => if List.exists (fn m => #dir m = #dir l) seen then go (rest, seen)
                            else go (rest @ requiresNow l, seen @ [l])
        in go (words, []) end
      fun provides (l : library) ((k, n) : string * string) : bool =
        List.exists (fn (k', n') => n' = n andalso (k = "" orelse k = k')) (publicOf l)

      (* the clients of every library: each source of the tree and of the
         trees --clients names, by its path from its tree's top and its path
         to read *)
      val clientFiles : (string * string) list =
        List.map (fn p => (p, p)) sources
        @ List.concat (List.map (fn top => List.map (fn r => (r, top ^ "/" ^ r))
                                                    (List.filter (fn r => isSource r andalso not (ignored r)) (walk top)))
                                (#clients opts))
      (* a file is a client of a library outside it, or in a library nested
         in it; and not a build's that the library names a friend, which sees
         all it declares anyway *)
      fun clientOf (l : library) (rel : string) : bool =
        not (under (#dir l) rel) orelse (case libraryOf rel of SOME d => d <> #dir l | NONE => false)

      (* ---- one library ---- *)
      fun migrateLibrary (l : library) : change option =
        let
          val text = readText (#build l)
          val header = headerOf l
          val marked = String.isSubstring mark text
          val unread = List.filter (fn (p, _) => not (#parsed (factsOf p))) (#units l)
          val values = List.concat (List.map (fn (p, anns) => if final anns then [] else #values (factsOf p)) (#units l))
          val fixity = List.exists (fn (p, anns) => not (final anns) andalso #fixity (factsOf p)) (#units l)
          fun keep (category, why) = (note (category, #name l ^ why); NONE)
        in
          if #dir l = basisDir then keep ("left: the Basis Library, which has no boundary", "")
          else if generated (#build l) then keep ("left: generated", "")
          else if kept (#build l) then keep ("left: kept", "")
          else if not (isSome (#plan l)) then keep ("judgement: cannot plan", "")
          else if isSome header andalso not marked then keep ("left: a header a person wrote", "")
          else if not (List.null unread) then
            keep ("judgement: a source it cannot read alone", ": " ^ String.concatWith " " (List.map #1 unread))
          else if not (List.null values) then
            keep ("judgement: a value at the top level, which a header cannot export", ": " ^ String.concatWith " " values)
          else if fixity then keep ("judgement: a fixity at the top level", "")
          else
            let
              val declared = declaredBy l
              (* what its clients use of it *)
              val used =
                List.foldl (fn ((rel, path), acc) =>
                              if not (clientOf l rel) then acc
                              else List.foldl (fn ((k, n), acc) =>
                                                 List.foldl (fn (d as (k', n'), acc) =>
                                                               if n' = n andalso (k = "" orelse k = k') andalso not (member d acc)
                                                               then d :: acc else acc) acc declared)
                                              acc (#uses (factsOf path)))
                           [] clientFiles
              (* and each signature of its own those ascribe, or a structure
                 inside them (D8) *)
              val claims = List.concat (List.map (fn (p, anns) => if final anns then [] else #claims (factsOf p)) (#units l))
              val ascribed =
                List.mapPartial (fn (kind, path, s) =>
                                   let val top = hd (String.fields (fn c => c = #".") path)
                                   in if member (kind, top) used andalso member ("signature", s) declared
                                      then SOME ("signature", s) else NONE end) claims
                @ List.mapPartial (fn (f, s) => if member ("functor", f) used andalso member ("signature", s) declared
                                                then SOME ("signature", s) else NONE)
                                  (List.concat (List.map (fn (p, anns) => if final anns then [] else #parameters (factsOf p)) (#units l)))
                @ List.mapPartial (fn s => if member ("signature", s) declared then SOME ("signature", s) else NONE)
                                  (List.concat (List.map (fn (p, anns) => if final anns then [] else #comments (factsOf p)) (#units l)))
              val exports = sortNames (used @ ascribed)
              (* what it is written on, and each library it uses a name of
                 that it reached through another *)
              val written = requiresOf l
              val direct = List.mapPartial libraryNamed written
              val own = usedBy l
              val reached = List.filter (fn m => not (List.exists (fn d => #dir d = #dir m) direct)) (closureOf written)
              val added = List.map #name (List.filter (fn m => List.exists (fn u => provides m u) own) reached)
              val requires = written @ List.filter (fn a => not (List.exists (fn w => nameOf w = a) written)) (sortStrings added)
              val unused = List.filter (fn d => not (List.exists (fn u => provides d u) own)) direct
              val () = List.app (fn d => note ("noted: a library it requires and uses nothing of", #name l ^ ": " ^ #name d)) unused
              val () = decided := StringMap.insert (!decided, #dir l, (SOME exports, requires))
              val ls = lexemes (#build l, text)
              (* the text: the old header's requires and exports, or its
                 libraries, out, and the header in at the first word *)
              val new =
                case header of
                  NONE =>
                    let val h = headerText (List.map importText requires, exports)
                    in
                      (* in the place of its libraries, or before its first word *)
                      case partExtent (ls, "libraries", "end") of
                        SOME (a, b) => String.substring (text, 0, a) ^ String.substring (h, 0, size h - 1) ^ String.extract (text, b, NONE)
                      | NONE => splice (text, case ls of x :: _ => #start x | [] => size text, h)
                    end
                | SOME _ =>
                    let
                      val h = headerText (List.map importText requires, exports)
                      (* where it wrote its requires, mark and exports: in
                         their place, where nothing else stands between them *)
                      val spans = List.mapPartial (fn x => x)
                                    [partExtent (ls, "requires", "end"), partExtent (ls, "exports", ")"),
                                     Option.map (fn i => (i, i + size mark)) (findSub (mark, text))]
                      val a = List.foldl Int.min (size text) (List.map #1 spans)
                      val b = List.foldl Int.max 0 (List.map #2 spans)
                      val between = List.foldl (fn ((x, y), s) => String.substring (s, 0, x - a) ^ String.implode (List.tabulate (y - x, fn _ => #" "))
                                                                  ^ String.extract (s, y - a, NONE))
                                               (String.substring (text, a, b - a)) spans
                    in
                      if CharVector.all Char.isSpace between
                      then String.substring (text, 0, a) ^ String.substring (h, 0, size h - 1) ^ String.extract (text, b, NONE)
                      else
                        let
                          val t = text
                          val t = case partExtent (lexemes (#build l, t), "exports", ")") of SOME (a, b) => cut (t, a, b) | NONE => t
                          val t = case partExtent (lexemes (#build l, t), "requires", "end") of SOME (a, b) => cut (t, a, b) | NONE => t
                          val t = case findSub (mark, t) of SOME i => cut (t, i, i + size mark) | NONE => t
                          val first = case lexemes (#build l, t) of x :: _ => #start x | [] => size t
                        in splice (t, first, h) end
                    end
              val hiddenNames = List.filter (fn d => not (member d exports)) (sortNames declared)
              val hidden = List.length hiddenNames
              val () = if List.null hiddenNames then ()
                       else note ("names a header hides", #name l ^ ": "
                                  ^ String.concatWith " " (List.map (fn (k, n) => k ^ " " ^ n) hiddenNames))
            in
              if new = text then (note ("unchanged: a header it wrote", #name l); NONE)
              else
                (note (if isSome header then "header written again" else "header written",
                       #name l ^ ": exports " ^ Int.toString (length exports) ^ " of " ^ Int.toString (length declared)
                       ^ " names, hides " ^ Int.toString hidden
                       ^ (if List.null added then "" else "; requires " ^ String.concatWith " " added ^ " too"));
                 SOME {path = #build l, text = new})
            end
        end
      val libraryChanges = List.mapPartial migrateLibrary (ordered ())

      (* ---- one program ---- *)
      fun friendOf (l : library, build : string) : bool =
        case headerOf l of
          SOME {friends, ...} => List.exists (fn f => B.isFriend (#dir l, f, build)) friends
        | NONE => false
      (* what a program's scope shows: what it names, and what a library with
         no header among those is written on, as it is where the program does
         not name it itself (BasisManifest.scopes) *)
      fun visible (build : string, words : string list) : (string * string) list =
        let
          fun headed l = isSome (headerOf l) orelse (case StringMap.find (!decided, #dir l) of SOME (SOME _, _) => true | _ => false)
          fun shown l = if headed l andalso not (friendOf (l, build)) then publicOf l else declaredBy l
          fun go ([], seen, acc) = acc
            | go (w :: rest, seen, acc) =
                case libraryNamed w of
                  NONE => go (rest, seen, acc)
                | SOME l => if member (#dir l) seen then go (rest, seen, acc)
                            else go (rest @ (if headed l then [] else requiresNow l), #dir l :: seen, acc @ shown l)
        in go (words, [], []) end
      fun migrateProgram (build : string) : change option =
        case planOf build of
          NONE => (note ("judgement: cannot plan", build); NONE)
        | SOME plan =>
            let
              val text = readText build
              val keep = kept build
              val here = OS.Path.dir build
              (* what it names of each library not its own, by the library,
                 its own files only *)
              val own = List.filter (fn (b, _) => b = build) (#references plan)
              val reached =
                List.foldl (fn ((_, target), acc) =>
                              case libraryOf target of
                                NONE => acc
                              | SOME d =>
                                  if d = basisDir orelse String.isSubstring "/generated/" target then acc
                                  else case List.partition (fn (d', _) => d' = d) acc of
                                         ([(_, ts)], rest) => rest @ [(d, ts @ [target])]
                                       | _ => acc @ [(d, [target])])
                           [] own
              fun whole (l : library, targets : string list) =
                List.all (fn (p, _) => member p targets) (#units l) andalso List.all isSource targets
              val (wholes, others) =
                List.partition (fn (d, ts) => case libraryAt d of SOME l => whole (l, ts) | NONE => false) reached
              val () = List.app (fn (d, ts) =>
                         let val l = libraryAt d
                             val friend = case l of SOME l => friendOf (l, build) | NONE => false
                             val (subs, files) = List.partition (fn t => String.isSuffix ".build" t) ts
                         in
                           if friend then note ("noted: a friend reaches in", build ^ ": " ^ d)
                           else
                             (List.app (fn s => note ("judgement: a build file of a library used from outside it", build ^ ": use " ^ s)) subs;
                              if List.null files then ()
                              else note ("judgement: part of a library listed", build ^ ": " ^ d ^ " (" ^ Int.toString (length files)
                                         ^ " of " ^ (case l of SOME l => Int.toString (length (#units l)) | NONE => "?") ^ " files)"))
                         end) others
              val wholeNames = List.mapPartial (fn (d, _) => Option.map #name (libraryAt d)) wholes
              (* its libraries once those are named, and the units that stay *)
              val words = #libraries plan @ List.filter (fn n => not (List.exists (fn w => nameOf w = n) (#libraries plan))) wholeNames
              val removed = List.concat (List.map #2 wholes)
              val units = List.filter (fn (p, _) => not (member p removed)) (P.units (#steps plan))
              (* each name its units use, that they do not declare, that the
                 Basis Library does not have and its scope would not show,
                 and that a library it loads gives: that library, named *)
              val declared = List.concat (List.map (fn (p, _) => #declares (factsOf p)) units)
              val shows = visible (build, words)
              val loads = closureOf words
              val needed =
                List.foldl (fn ((p, _), acc) =>
                              List.foldl (fn (u as (k, n), acc) =>
                                            if List.exists (fn (_, m) => m = n) declared orelse inBasis n
                                               orelse List.exists (fn (k', n') => n' = n andalso (k = "" orelse k = k')) shows
                                            then acc
                                            else case List.find (fn m => provides m u) loads of
                                                   SOME m => if member (#name m) acc then acc else acc @ [#name m]
                                                 | NONE => acc) acc (#uses (factsOf p)))
                           [] units
              val needed = List.filter (fn n => not (List.exists (fn w => nameOf w = n) words)) needed
            in
              if List.null wholes andalso List.null needed then NONE
              else if keep then
                (List.app (fn n => note ("blocked: a kept build would need a library named", build ^ ": " ^ n)) needed;
                 List.app (fn (d, _) => note ("left: a kept build lists a whole library", build ^ ": " ^ d)) wholes;
                 NONE)
              else
                let
                  (* the files listed of each whole library out, then any
                     files block left empty *)
                  fun drop (t, []) = t
                    | drop (t, target :: rest) =
                        let
                          fun spelt (l : BF.lexeme) =
                            case #word l of
                              BF.W s => tidy (P.concat false (here, s)) = target
                            | BF.S s => tidy (P.concat false (here, s)) = target
                        in
                          case List.find spelt (lexemes (build, t)) of
                            SOME l => drop (cut (t, #start l, #stop l), rest)
                          | NONE => drop (t, rest)
                        end
                  fun empties t =
                    let
                      fun go (a :: b :: rest) = if isWord "files" a andalso isWord "end" b then SOME (#start a, #stop b) else go (b :: rest)
                        | go _ = NONE
                    in case go (lexemes (build, t)) of SOME (a, b) => empties (cut (t, a, b)) | NONE => t end
                  val t = empties (drop (text, removed))
                  val more = List.filter (fn n => not (List.exists (fn w => nameOf w = n) (#libraries plan))) (wholeNames @ needed)
                  val t =
                    case partExtent (lexemes (build, t), "libraries", "end") of
                      SOME (_, b) => splice (t, b - 3, String.concatWith " " more ^ " ")
                    | NONE =>
                        let val first = case lexemes (build, t) of x :: _ => #start x | [] => size t
                        in splice (t, first, "libraries " ^ String.concatWith " " more ^ " end\n") end
                in
                  List.app (fn (d, ts) => note ("whole library listed: named", build ^ ": " ^ d ^ " (" ^ Int.toString (length ts) ^ " files)")) wholes;
                  List.app (fn n => note ("library named: its units use it, and their scope would not show it", build ^ ": " ^ n)) needed;
                  SOME {path = build, text = t}
                end
            end
      val programChanges =
        List.mapPartial (fn b => if isSome (libraryOf b) then NONE    (* a library's, or a build file it uses *)
                                 else if generated b then NONE
                                 else migrateProgram b)
                        (List.filter (fn b => not (ignored b)) builds)
      val changes = libraryChanges @ programChanges
      val () = if #write opts then List.app (fn {path, text} => writeText (path, text)) changes else ()
      (* the report: each category, its lines in order *)
      val categories = sortStrings (List.map #1 (!report))
      val body =
        String.concat (List.map (fn c =>
          let val ls = List.rev (List.mapPartial (fn (c', l) => if c = c' then SOME l else NONE) (!report))
          in c ^ ": " ^ Int.toString (length ls) ^ "\n" ^ String.concat (List.map (fn l => if l = "" then "" else "  " ^ l ^ "\n") ls) end)
          categories)
      val summary = "build files: " ^ Int.toString (length builds) ^ ", libraries: " ^ Int.toString (length libraries)
                    ^ ", sources read: " ^ Int.toString (StringMap.numItems (!known))
                    ^ ", changed: " ^ Int.toString (length changes) ^ (if #write opts then " (written)" else " (not written)") ^ "\n"
    in
      case #report opts of
        SOME f => writeText (f, summary ^ body)
      | NONE => ();
      print (summary ^ body);
      length changes
    end

  fun usage () =
    raise Usage "usage: rune-migrate [--write] [--report FILE] [--keep FILE] [--clients DIR]... [--ignore PREFIX]...\n\
                \                    [--path NAME=DIR]... [--lib DIR] LIST\n\
                \LIST names the tree's files, one a line from its top, which is the current directory: - for stdin"

  fun main () =
    let
      fun parse (args, opts : options) =
        case args of
          [] => opts
        | "--write" :: rest => parse (rest, {write = true, report = #report opts, keep = #keep opts, clients = #clients opts,
                                             ignore = #ignore opts, lib = #lib opts, list = #list opts})
        | "--report" :: f :: rest => parse (rest, {write = #write opts, report = SOME f, keep = #keep opts, clients = #clients opts,
                                                   ignore = #ignore opts, lib = #lib opts, list = #list opts})
        | "--keep" :: f :: rest => parse (rest, {write = #write opts, report = #report opts, keep = #keep opts @ lines (readText f),
                                                 clients = #clients opts, ignore = #ignore opts, lib = #lib opts, list = #list opts})
        | "--clients" :: d :: rest => parse (rest, {write = #write opts, report = #report opts, keep = #keep opts,
                                                    clients = #clients opts @ [d], ignore = #ignore opts, lib = #lib opts,
                                                    list = #list opts})
        | "--ignore" :: p :: rest => parse (rest, {write = #write opts, report = #report opts, keep = #keep opts,
                                                   clients = #clients opts, ignore = #ignore opts @ [p], lib = #lib opts,
                                                   list = #list opts})
        | "--lib" :: d :: rest => parse (rest, {write = #write opts, report = #report opts, keep = #keep opts, clients = #clients opts,
                                                ignore = #ignore opts, lib = d, list = #list opts})
        | "--path" :: v :: rest =>
            (case String.fields (fn c => c = #"=") v of
               name :: value :: more =>
                 (BuildFile.variables := StringMap.insert (!BuildFile.variables, name, String.concatWith "=" (value :: more));
                  parse (rest, opts))
             | _ => usage ())
        | a :: rest => if String.isPrefix "-" a andalso a <> "-" then usage ()
                       else parse (rest, {write = #write opts, report = #report opts, keep = #keep opts, clients = #clients opts,
                                          ignore = #ignore opts, lib = #lib opts, list = a})
      val opts = parse (CommandLine.arguments (),
                        {write = false, report = NONE, keep = [], clients = [], ignore = [], lib = "lib", list = ""})
      val () = if #list opts = "" then usage () else ()
    in
      ignore (run opts); OS.Process.exit OS.Process.success
    end
    handle Usage m => (TextIO.output (TextIO.stdErr, m ^ "\n"); OS.Process.exit OS.Process.failure)
end

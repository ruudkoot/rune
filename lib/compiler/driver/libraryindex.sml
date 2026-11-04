(* A library's index (BasisManifest.index): what each file of the library
   provides and requires, from its build file DIR/library.build, read as any
   build file is (CompilerProject) -- each file's class and host by its
   annotations ("always", "demand", "seal", "final"; "host=swap", "host=no"),
   the libraries it is written on by `requires` or `libraries` -- and from
   the files: what each declares (Deps), and what it uses that the files
   before it, the Basis Library or the libraries it is written on provide. A
   file that uses a name only a file after it provides is refused.

   An index is never a file in the tree: it is the one query, index, which
   every reader asks -- the driver, its selection and its -j children, the
   compiler's API and its analysis, and runedoc -- and a record in the store
   that the query keeps, by the library's place (the build-system roadmap's
   D13). A record holds what the index was made of: the bytes of each build
   file and source it read, by their hashes, and the index of each library
   it was made against, by the hash of that index. It is believed only where
   all of them are what they were, so that an edit of any of them is a miss,
   and a stale index is impossible: a file's hash is taken again where its
   stat is not what it was or not racily clean (UnitStore), and a library
   it was made against is asked again. What each file is to the index is
   kept in the record too, by the file's hash and the fixity it was read
   in, so that an edit costs the files edited. --no-cache turns units off,
   not the index: a compile reads the store's records then, and writes none. *)
structure LibraryIndex =
struct
  structure P = CompilerProject
  structure B = BasisManifest
  structure S = UnitStore
  type entry = B.entry
  type index = B.index
  exception Usage = B.Usage

  (* a library's directory as a message names it: by where it is in the
     libraries, wherever those are *)
  fun libraryShown (root : string, dir : string) : string =
    let val prefix = root ^ "/"
    in if String.isPrefix prefix dir then "lib/" ^ String.extract (dir, size prefix, NONE) else dir end

  (* a clash (BasisManifest.clashes), as an error says it (D9), with what
     answers it: a rename where the second is imported, by the name an import
     gives it *)
  fun clashText (root : string) (name : string, first : string, second : string) : string =
    let val prefix = root ^ "/"
        val imported = if String.isPrefix prefix second then String.extract (second, size prefix, NONE) else second
    in
      "this scope has " ^ name ^ " from both "
      ^ (if first = "" then "the Basis Library" else "the library " ^ libraryShown (root, first))
      ^ " and the library " ^ libraryShown (root, second) ^ ": rename one where it is imported, as "
      ^ imported ^ " (KIND " ^ name ^ " as OTHER) does (docs/build.md, Clashes)"
    end

  fun readText (f : string) : string =
    let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end

  (* The virtual modules a file declares at its top level, and those it
     exports (_export), KIND and NAME each (docs/build.md, Virtual
     libraries; D22) *)
  fun dynamicModules (prog : Ast.program) : {virtuals : (string * string) list, exports : (string * string) list} =
    let
      fun bare (Ast.StrAscribe (e, _, _, _, _)) = bare e
        | bare e = e
      fun top (d, acc as (vs, xs)) =
        case d of
          Ast.DStructure (bs, _, _) =>
            List.foldl (fn ({name, strexp, ...} : Ast.strbind, (vs, xs)) =>
                          case bare strexp of
                            Ast.StrDynamic (Ast.DynamicVirtual _, _, _, _, _) => (vs @ [("structure", name)], xs)
                          | Ast.StrExport _ => (vs, xs @ [("structure", name)])
                          | _ => (vs, xs)) acc bs
        | Ast.DFunctor (bs, _, _) =>
            List.foldl (fn ({name, body, ...} : Ast.funbind, (vs, xs)) =>
                          case body of
                            Ast.StrDynamic (Ast.DynamicFunctor (Ast.DynamicVirtual _), _, _, _, _) => (vs @ [("functor", name)], xs)
                          | Ast.StrExport _ => (vs, xs @ [("functor", name)])
                          | _ => (vs, xs)) acc bs
        | Ast.DLocal (_, b, _, _) => List.foldl top acc b
        | _ => acc
      val (vs, xs) = List.foldl top ([], []) prog
    in {virtuals = vs, exports = xs} end
  fun virtualTokens (toks : Lexer.item vector) : int =
    Vector.foldl (fn ((Token.VIRTUAL, _), n) => n + 1 | (_, n) => n) 0 toks

  fun hash (text : string) : string = Pickle.hash text

  (* ---- what a file is to its library's index, by its text ----
     what Deps finds of it, the virtual modules it declares and the modules it
     exports (_export), how many times it says _virtual, and the fixity
     directives it adds to what it is read in, newest first *)
  type facts = {deps : Deps.file, virtuals : (string * string) list, exports : (string * string) list, said : int,
                fixity : (string * Fixity.fixity) list}

  local
    open Pickle
    fun kindCode k = case k of Deps.Str => 0 | Deps.Sig => 1 | Deps.Fun => 2 | Deps.Tycon => 3
    fun codeKind n = case n of 0 => Deps.Str | 1 => Deps.Sig | 2 => Deps.Fun | 3 => Deps.Tycon | _ => raise Bad "a kind"
    fun name (w, (k, n)) = (nat (w, kindCode k); string (w, n))
    fun rname r = let val k = codeKind (rnat r) in (k, rstring r) end
    fun pair (w, (a, b)) = (string (w, a); string (w, b))
    fun rpair r = let val a = rstring r in (a, rstring r) end
    fun fixity (w, (n, f)) =
      (string (w, n); case f of Fixity.Nonfix => nat (w, 0) | Fixity.Infix p => (nat (w, 1); nat (w, p))
                               | Fixity.Infixr p => (nat (w, 2); nat (w, p)))
    fun rfixity r =
      let val n = rstring r
      in (n, case rnat r of 0 => Fixity.Nonfix | 1 => Fixity.Infix (rnat r) | 2 => Fixity.Infixr (rnat r) | _ => raise Bad "a fixity") end
    fun break (w, ({file, start, stop} : Source.span, what)) = (string (w, file); nat (w, start); nat (w, stop); string (w, what))
    fun rbreak r =
      let val file = rstring r val start = rnat r val stop = rnat r
      in ({file = file, start = start, stop = stop}, rstring r) end
  in
    fun writeFacts (w, {deps = {path, declares, uses, free, breaks, values, hides, mentions, prelude}, virtuals, exports, said,
                        fixity = fx} : facts) =
      (string (w, path); list name (w, declares); list name (w, uses); list name (w, free); list break (w, breaks);
       list string (w, values); bool (w, hides); list string (w, mentions); bool (w, prelude);
       list pair (w, virtuals); list pair (w, exports); nat (w, said); list fixity (w, fx))
    fun readFacts r : facts =
      let
        val path = rstring r val declares = rlist rname r val uses = rlist rname r val free = rlist rname r
        val breaks = rlist rbreak r val values = rlist rstring r val hides = rbool r val mentions = rlist rstring r
        val prelude = rbool r val virtuals = rlist rpair r val exports = rlist rpair r val said = rnat r
        val fx = rlist rfixity r
      in
        {deps = {path = path, declares = declares, uses = uses, free = free, breaks = breaks, values = values, hides = hides,
                 mentions = mentions, prelude = prelude},
         virtuals = virtuals, exports = exports, said = said, fixity = fx}
      end

    (* an index's bytes, and back *)
    fun writeIndex (w, {libraries, scope, header, fixities, inline, inlineValues, lines} : index) =
      (list string (w, libraries); option (list pair) (w, scope);
       option (fn (w, {friends, views, virtuals, implements} : B.header) =>
                  (list string (w, friends); list (fn (w, (v, es)) => (string (w, v); list pair (w, es))) (w, views);
                   list pair (w, virtuals); list pair (w, implements))) (w, header);
       list fixity (w, fixities); list string (w, inline); list string (w, inlineValues);
       (* every name of the lines once, in a table, and each line's by its
          place there: a line's names and its class and host are most of
          the bytes, which every compile reads and holds to their hash *)
       let
         val table = ref StringMap.empty : int StringMap.map ref
         val order = ref [] : string list ref
         fun place n = case StringMap.find (!table, n) of
                         SOME i => i
                       | NONE => let val i = StringMap.numItems (!table)
                                 in table := StringMap.insert (!table, n, i); order := n :: !order; i end
         val coded = List.map (fn {file, class, host, provides, requires} : B.line =>
                                 (file, place class, place host, List.map place provides, List.map place (requires ()))) lines
       in
         list string (w, List.rev (!order));
         list (fn (w, (file, class, host, provides, requires)) =>
                 (string (w, file); nat (w, class); nat (w, host); list nat (w, provides); list nat (w, requires))) (w, coded)
       end)
    fun readIndex r : index =
      let
        val libraries = rlist rstring r
        val scope = roption (rlist rpair) r
        val header = roption (fn r => let val friends = rlist rstring r
                                          val views = rlist (fn r => let val v = rstring r in (v, rlist rpair r) end) r
                                          val virtuals = rlist rpair r
                                      in {friends = friends, views = views, virtuals = virtuals, implements = rlist rpair r} end) r
        val fixities = rlist rfixity r
        val inline = rlist rstring r
        val inlineValues = rlist rstring r
        val names = Vector.fromList (rlist rstring r)
        fun name r = Vector.sub (names, rnat r) handle Subscript => raise Bad "a name of no line"
        (* what a file requires, which a compile asks of few files: passed
           over here, and read from its place when it is asked *)
        fun skip (_, 0) = () | skip (r, k) = (ignore (rnat r); skip (r, k - 1))
        val lines = rlist (fn r => let val file = rstring r val class = name r val host = name r
                                       val provides = rlist name r
                                       val {s, pos} = r
                                       val at = !pos
                                       val () = skip (r, rnat r)
                                   in {file = file, class = class, host = host, provides = provides,
                                       requires = fn () => rlist name {s = s, pos = ref at}} end) r
      in {libraries = libraries, scope = scope, header = header, fixities = fixities, inline = inline,
          inlineValues = inlineValues, lines = lines} end
  end

  (* ---- an index as text: what --basis-index prints ---- *)
  fun exportWords es = String.concatWith " " (List.map (fn (k,n) => k ^ ":" ^ n) es)
  fun text ({libraries, scope, header, fixities, inline, inlineValues, lines} : index) : string =
    let
      val scopeColumn = case (scope, header) of (NONE, _) => "" | (_, SOME _) => "" | (SOME [], _) => " | -"
                                              | (SOME es, _) => " | " ^ exportWords es
      fun fixityWord f = case f of Fixity.Infix p => "infix " ^ Int.toString p | Fixity.Infixr p => "infixr " ^ Int.toString p
                                 | Fixity.Nonfix => "nonfix"
    in
      String.concat (
        "# The index of a library, from its library.build (rune --basis-index)\n"
        :: List.map (fn l => "# library: " ^ l ^ "\n") libraries
        @ (case (scope, header) of
             (SOME es, SOME {friends, views, virtuals, implements}) =>
               ["# exports: " ^ (if List.null es then "-" else exportWords es) ^ "\n"]
               @ (if List.null virtuals then [] else ["# virtual: " ^ exportWords virtuals ^ "\n"])
               @ (if List.null implements then [] else ["# implements: " ^ exportWords implements ^ "\n"])
               @ (if List.null friends then [] else ["# friends: " ^ String.concatWith " " friends ^ "\n"])
               @ List.map (fn (v, es) => "# view: " ^ v ^ " " ^ exportWords es ^ "\n") views
               @ List.map (fn (n, f) => "# fixity: " ^ fixityWord f ^ " " ^ n ^ "\n") fixities
           | _ => [])
        @ (if List.null inline then [] else ["# inline: " ^ String.concatWith " " inline ^ "\n"])
        @ (if List.null inlineValues then [] else ["# inline val: " ^ String.concatWith " " inlineValues ^ "\n"])
        @ List.map (fn {file, class, host, provides, requires} =>
                      file ^ " | " ^ class ^ " | " ^ host ^ " | " ^ String.concatWith " " provides ^ " | " ^ String.concatWith " " (requires ())
                      ^ scopeColumn ^ "\n")
                   lines)
    end

  (* ---- making an index ---- *)

  (* What the making of an index read: each build file and source, by its
     path from the library's directory, with its stat as it was before it was
     read, and the hash of its bytes; and what each source was to it, by the
     hash of its text, its name and the fixity it was read in *)
  type read = {path : string, stamp : S.stamp option, hash : string}
  type made = {index : index, read : read list, facts : (string * facts) list}

  (* the fixity a file is read in, as a key: its directives, newest first *)
  fun fixityKey (fx : Fixity.env) : string =
    String.concatWith " " (List.map (fn (n, f) => n ^ (case f of Fixity.Nonfix => "~" | Fixity.Infix p => "<" ^ Int.toString p
                                                              | Fixity.Infixr p => ">" ^ Int.toString p)) (#list fx))

  (* Whether the libraries in root have a Basis Library: a directory of them
     may have none, which runedoc documents a library of as written on
     nothing; and its entries, if it has *)
  fun hasBasis (root : string) : bool = Source.probe (root ^ "/basis/library.build")
  fun basisOf (root : string, index : string -> index) : entry list =
    if hasBasis root then B.entriesOf (root ^ "/basis", index (root ^ "/basis")) else []

  (* The index of the library in dir, made from its build file and its
     files; index, the index of another library, known what a file was to a
     making before, by its key, and hashed the hash of a file whose stat is
     what it was then, racily clean. warnings says what it finds that a
     client cannot act on: a library with no header, units that are not
     well-formed *)
  fun make {dir : string, root : string, warnings : bool, windows : bool, index : string -> index,
            known : string -> facts option, hashed : string * S.stamp option -> string option} : made =
    let
      val file = OS.Path.joinDirFile {dir = dir, file = "library.build"}
      val libDir = root ^ "/basis"
      val here = P.directory windows (P.normalize windows file)
      (* a path of the plan, from the library's directory *)
      fun relative p =
        OS.Path.mkCanonical (if here <> "" andalso String.isPrefix (here ^ "/") p then String.extract (p, size here + 1, NONE) else p)
      val reads = ref [] : read list ref
      fun read path =
        let val stamp = S.statOf path
            val text = readText path handle IO.Io _ => raise P.Invalid ("cannot read the build file " ^ path)
        in reads := {path = relative path, stamp = stamp, hash = hash text} :: !reads; {text = text, revision = ""} end
      val plan = P.planWith {file = file, windows = windows, readBuild = read, hosts = true} handle P.Invalid m => raise Usage m
      val header = #header plan
      val libs = #libraries plan
      val (boundary, inside) = case #steps plan of [P.SLibrary (es, ss)] => (SOME es, ss) | ss => (NONE, ss)
      fun held (P.SUnit _) = ()
        | held (P.SUse (_, ss)) = List.app held ss
        | held (P.SLibrary _) = raise Usage (file ^ ": a library has one outer export boundary")
        | held (P.SImplements _) = raise Usage (file ^ ": a library's build file lists its files, annotated; no more")
      val () = List.app held inside
      val () = Option.app (fn {friends, ...} =>
        List.app (fn f => if OS.Path.isAbsolute f then raise Usage (file ^ ": a friend is a path from the library: " ^ f) else ()) friends) header
      (* what a library with no header is written on, it sees whole: its
         files see all before them, so a rename there means nothing (D15) *)
      val () = if isSome header then ()
               else List.app (fn l => if List.null (#renames (B.importOf l)) then ()
                                      else raise Usage (file ^ ": a library with no header renames nothing it is written on;"
                                                        ^ " a header's requires does (docs/build.md, Clashes)")) libs
      val listed = List.map (fn (p, anns) => (relative p, anns)) (P.units inside)
      val inl = #inline plan
      val inlVals = #inlineValues plan
      fun kindName k = case k of BuildFile.Str => "structure" | BuildFile.Sig => "signature"
                              | BuildFile.Fun => "functor" | BuildFile.Ty => "type" | BuildFile.Fix => "fixity"
      val exports = Option.map (List.map (fn (k,n) => (kindName k,n))) boundary
      val isBasisDir = OS.Path.mkCanonical dir = OS.Path.mkCanonical (root ^ "/basis")
      (* a seal of a view of the Basis Library is seal@VIEW (D12) *)
      fun classOf anns =
        case List.filter (String.isPrefix "view=") anns of
          [] => P.classOf anns
        | views =>
            if not isBasisDir then raise Usage (file ^ ": a view is the Basis Library's; a library's own view of it is a seal file inside its boundary")
            else if P.classOf anns <> "seal" then raise Usage (file ^ ": the files of a view of the Basis Library are seal files")
            else "seal@" ^ String.extract (List.last views, 5, NONE)
      fun hostOf anns =
        case List.filter (fn a => String.isPrefix "host=" a) anns of
          [] => "yes" | hs => String.extract (List.last hs, 5, NONE)
      (* what the Basis Library and the libraries this one is written on
         provide, from their indexes *)
      val isBasis = OS.Path.mkCanonical dir = OS.Path.mkCanonical libDir
      fun requiresOf d = #libraries (index d)
      fun virtualsOf d = case #header (index d) of SOME {virtuals, ...} => virtuals | NONE => []
      fun implementsOf d = case #header (index d) of SOME {implements, ...} => implements | NONE => []
      val written = if isBasis then []
                    else List.map (fn d => (d, B.entriesOf (d, index d)))
                                  (case libs of
                                     [] => []
                                   | _ => B.librariesWith {requires = requiresOf, virtuals = virtualsOf, implements = implementsOf} (root, libs))
      val () = if isBasis orelse isSome header orelse not warnings then ()
               else (Error.warn ({file = file, start = 0, stop = 0},
                                 "this library has no header: all it declares is public, and its libraries are transitive (docs/build.md, A library's header)");
                     Error.flushWarnings ())
      val outside = if isBasis then [] else basisOf (root, index) @ List.concat (List.map #2 written)
      (* with a header, it sees the Basis Library and what it requires alone,
         through what a client of it would (BasisManifest) *)
      val scopes = B.scopes {root = root, building = SOME file, names = libs, headed = isSome header, libraries = written,
                             view = NONE, requires = requiresOf}
      fun usable (e : entry) =
        if not (isSome header) orelse #dir e = libDir then B.public e
        else B.seenNames (#program scopes, e)
      (* two imports of one name in its scope (D9) *)
      val () = if not (isSome header) then ()
               else case B.clashes (#program scopes, outside, libDir) of
                      [] => ()
                    | clash :: _ => raise Usage (file ^ ": " ^ clashText root clash)
      val provided = List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (usable e))
                                StringMap.empty outside
      (* and what of those a boundary, or not being required, hides *)
      val hidden = List.foldl (fn (e : entry, m) =>
                                 let val public = B.public e
                                 in List.foldl (fn (n, m) =>
                                      if StringMap.member (provided, n) then m
                                      else StringMap.insert (m, n, (#dir e, List.exists (fn p => p = n) public))) m (#provides e) end)
                              StringMap.empty outside
      (* The fixity a file of the library is read in: the initial basis's, what
         it requires exports, and what its files before say; a file may be in
         a directory below the library's: sized/int32.sml *)
      val imported = List.concat (List.map (#fixities o index)
                                           (if isSome header then List.map #dir (#program scopes) else List.map #1 written))
      (* each file as its index has it: by its key, what was found before,
         else its syntax in the fixity the files before it leave *)
      val factsRev = ref [] : (string * facts) list ref
      val (analysedRev, afterAll) =
        List.foldl (fn ((p, anns), (acc, fx)) =>
                      let
                        val path = OS.Path.concat (dir, p)
                        val stamp = S.statOf path
                        (* a file whose stat is what it was is not read for its hash *)
                        val h = case hashed (p, stamp) of
                                  SOME h => h
                                | NONE => hash (readText path handle IO.Io _ => raise Usage ("cannot read " ^ path))
                        val () = reads := {path = p, stamp = stamp, hash = h} :: !reads
                        val key = hash (String.concatWith "\000" [h, path, fixityKey fx])
                        val f as {fixity = added, ...} =
                          case known key of
                            SOME f => f
                          | NONE =>
                              let
                                val toks = Lexer.tokenize (Source.load (Source.Ascii, path))
                                           handle IO.Io _ => raise Usage ("cannot read " ^ path)
                                val (prog, fx') = Parser.parseTokensWith (toks, fx)
                                val {virtuals, exports} = dynamicModules prog
                              in
                                {deps = Deps.analyse (p, prog), virtuals = virtuals, exports = exports, said = virtualTokens toks,
                                 fixity = List.take (#list fx', List.length (#list fx') - List.length (#list fx))}
                              end
                      in factsRev := (key, f) :: !factsRev; ((p, anns, f) :: acc, Fixity.extend (fx, added)) end)
                   ([], Fixity.extend (Fixity.initial, imported)) listed
      val analysed = List.map (fn (p, anns, f : facts) => (p, anns, #deps f)) (List.rev analysedRev)
      val dynamics = List.mapPartial (fn (p, anns, {virtuals, exports, said, ...} : facts) =>
                                        if hostOf anns = "only" then NONE else SOME (p, anns, {virtuals = virtuals, exports = exports}, said))
                                     (List.rev analysedRev)
      (* a span of a file whose facts were known, where it was not read *)
      fun loaded (sp : Source.span) =
        if isSome (Source.findFile (#file sp)) then () else ignore (Source.load (Source.Ascii, #file sp)) handle IO.Io _ => ()
      (* the rules (docs/units.md, Well-formed units), of the files Rune
         compiles: a strict library is held to them, and another is told of
         them once *)
      val () =
        case (Deps.illFormed (List.mapPartial (fn (_, anns, f) => if hostOf anns = "only" then NONE
                                                                  else SOME (Deps.unitOf (true, anns, f))) analysed),
              header) of
          ([], _) => ()
        | (findings, SOME {strict = true, ...}) =>
            (List.app (fn (sp, what) => (loaded sp; TextIO.output (TextIO.stdErr, Error.format (sp, Deps.notWellFormed what) ^ "\n"))) findings;
             raise Usage (file ^ ": a strict library's units are well-formed, and "
                          ^ (case findings of [_] => "one is not" | _ => Int.toString (List.length findings) ^ " are not")))
        | ((sp, what) :: rest, _) =>
            if not warnings then ()
            else (loaded sp;
                  Error.warn ({file = file, start = 0, stop = 0},
                              "this library" ^ (if List.null rest then " has a unit that is not well-formed, at "
                                                else " has " ^ Int.toString (1 + List.length rest) ^ " units that are not well-formed, the first at ")
                              ^ Source.describe sp ^ ", which is " ^ what ^ " (docs/units.md, Well-formed units)");
                  Error.flushWarnings ())
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      val providers = List.foldl (fn ((_, _, f : Deps.file), m) => List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) m
                                                                               (#declares f))
                                 provided analysed
      val declared = List.concat (List.map (fn (_,_,f : Deps.file) =>
        List.map (fn (k,n) => (Deps.kindName k,n)) (#declares f))
        (List.filter (fn (_,anns,_) => classOf anns <> "final") analysed))
      val ownFixity = List.take (#list afterAll, List.length (#list afterAll)
                                                 - List.length imported - List.length (#list Fixity.initial))
      val () = Option.app (List.app (fn exported as (k,n) =>
        if k = "fixity" then
          (if List.exists (fn (m, _) => m = n) ownFixity then ()
           else raise Usage (file ^ ": exports fixity " ^ n ^ ", which no source declares"))
        else if List.exists (fn declared => exported=declared) declared then ()
        else raise Usage (file ^ ": exports " ^ k ^ " " ^ n ^ ", which no source declares"))) exports
      (* a header's views are of what it exports *)
      val views = case header of NONE => [] | SOME {views, ...} => List.map (fn (v, es) => (v, List.map (fn (k,n) => (kindName k,n)) es)) views
      val () = List.app (fn (v, es) => List.app (fn e as (k, n) =>
                 if List.exists (fn x => x = e) (getOpt (exports, [])) then ()
                 else raise Usage (file ^ ": the view " ^ v ^ " has " ^ k ^ " " ^ n ^ ", which the library does not export")) es) views
      (* Virtual libraries (docs/build.md, Virtual libraries; D22): a
         virtual module is a header's, exported, declared _virtual at the top
         level of a file the library's build lists itself, and nothing before
         that file declares its name; an implementing library exports each
         module it implements, nothing else, of one library it requires, and
         names nothing that library declares from its first virtual module
         on, which comes after the implementation *)
      fun moduleText (k, n) = k ^ " " ^ n
      val virtuals = case header of NONE => [] | SOME {virtuals, ...} => List.map (fn (k, n) => (kindName k, n)) virtuals
      val implements = case header of NONE => [] | SOME {implements, ...} => List.map (fn (k, n) => (kindName k, n)) implements
      fun refuse message = raise Usage (file ^ ": " ^ message ^ " (docs/build.md, Virtual libraries)")
      val () = List.app (fn m =>
                 if not (List.exists (fn x => x = m) (getOpt (exports, [])))
                 then refuse ("says virtual " ^ moduleText m ^ ", which the library does not export")
                 else if not (List.exists (fn (_, _, {virtuals = vs, ...}, _) => List.exists (fn v => v = m) vs) dynamics)
                 then refuse ("says virtual " ^ moduleText m ^ ", which no source declares _virtual")
                 else ()) virtuals
      val () = List.app (fn (p, _, {virtuals = vs, ...}, count) =>
                 (List.app (fn m => if List.exists (fn v => v = m) virtuals then ()
                                    else refuse (p ^ " declares the " ^ moduleText m ^ " _virtual, and the header does not say virtual ("
                                                 ^ moduleText m ^ ")")) vs;
                  if count = List.length vs then ()
                  else refuse (p ^ " says _virtual of a module not at its top level, where a library's virtual modules are declared"))) dynamics
      (* the file the header names, from the library's directory as a unit's
         path is, which the plan splits the library at (CompilerPlan) *)
      val named = case header of SOME {virtualIn = SOME f, ...} => SOME (relative (P.concat windows (here, f))) | _ => NONE
      val () =
        case List.find (fn (_, _, {virtuals = vs, ...}, _) => not (List.null vs)) dynamics of
          NONE => ()
        | SOME (first, _, _, _) =>
            let
              val () = case named of
                         SOME f => if f = first then ()
                                   else refuse ("says virtual (...) in " ^ f ^ ", and the first file that declares a virtual module is "
                                                ^ first)
                       | NONE => ()
              val direct = List.exists (fn P.SUnit (q, _) => relative q = first | _ => false) inside
              fun earlier ((p, _, f : Deps.file) :: rest) =
                    if p = first then ()
                    else (case List.find (fn (_, n) => List.exists (fn (_, m) => m = n) virtuals) (#declares f) of
                            SOME (_, n) => refuse (p ^ " declares " ^ n ^ ", the name of a virtual module, before " ^ first
                                                   ^ " declares it virtual")
                          | NONE => earlier rest)
                | earlier [] = ()
            in
              if direct then earlier analysed
              else refuse (first ^ " declares a virtual module, and is listed in the library's build, not in one it uses")
            end
      val () = List.app (fn (p, _, {exports = xs, ...}, _) =>
                 List.app (fn m => if List.exists (fn i => i = m) implements orelse List.null implements then ()
                                   else refuse (p ^ " exports the " ^ moduleText m ^ ", which the header does not say it implements"))
                          xs) dynamics
      val () =
        if List.null implements then ()
        else
          let
            val direct = List.map (fn l => B.libraryDir (root, l)) libs
            fun virtualIn (d, es) = case es of (e : entry) :: _ => List.map (fn m => (m, d, es)) (B.virtualsOf e) | [] => []
            val declared = List.concat (List.map virtualIn (List.filter (fn (d, _) => List.exists (fn x => x = d) direct) written))
            val owners =
              List.map (fn m =>
                          if not (List.exists (fn (_, _, {exports = xs, ...}, _) => List.exists (fn x => x = m) xs) dynamics)
                          then refuse ("implements the " ^ moduleText m ^ ", which no source exports: _export " ^ moduleText m ^ " ...")
                          else case List.find (fn (v, _, _) => v = m) declared of
                                 SOME (_, d, es) => (d, es)
                               | NONE => refuse ("implements the " ^ moduleText m ^ ", which no library it requires declares virtual"))
                       implements
            val (owner, entries) = hd owners
            val () = case List.find (fn (d, _) => d <> owner) owners of
                       SOME (other, _) => refuse ("implements modules of two virtual libraries, " ^ libraryShown (root, owner) ^ " and "
                                                  ^ libraryShown (root, other) ^ ": a library implements one")
                     | NONE => ()
            val (_, tail) = B.virtualTail (B.virtualsOf (hd entries), entries)
            val late = List.concat (List.map #provides tail)
          in
            List.app (fn (p, _, f : Deps.file) =>
                        case List.find (fn (_, n) => List.exists (fn l => l = n) late) (#uses f) of
                          SOME (_, n) => refuse (p ^ " uses " ^ n ^ ", which " ^ libraryShown (root, owner)
                                                 ^ " declares from its first virtual module on, after its implementation")
                        | NONE => ()) analysed
          end
      val (lines, _) =
        List.foldl
          (fn ((p, anns, f : Deps.file), (acc, earlier)) =>
             let
               val provides = List.map #2 (#declares f)
               val requires = sorted (List.filter (fn n => StringMap.member (providers, n) andalso
                                                           not (List.exists (fn m => m = n) provides))
                                                  (List.map #2 (#uses f)))
               val () = List.app (fn n => if StringMap.member (earlier, n) then ()
                                          else raise Usage (file ^ ": " ^ p ^ " uses " ^ n ^
                                                                    ", which only a file after it provides"))
                                 requires
               (* a client would fail on it, and this library not (E28) *)
               val () = List.app (fn (kind, n) =>
                                    case StringMap.find (hidden, n) of
                                      SOME (library, exported) =>
                                        if kind = Deps.Tycon orelse StringMap.member (providers, n) then ()
                                        else if exported then
                                          raise Usage (file ^ ": " ^ p ^ " uses " ^ n ^ ", of the library " ^ libraryShown (root, library)
                                                               ^ ", which its header does not require")
                                        else raise Usage (file ^ ": " ^ p ^ " uses " ^ n ^ ", which the boundary of "
                                                                  ^ library ^ " does not export")
                                    | NONE => ())
                                 (#uses f)
               val line = {file = p, class = classOf anns, host = hostOf anns, provides = provides,
                           requires = fn () => requires}
             in (line :: acc, List.foldl (fn (n, m) => StringMap.insert (m, n, ())) earlier provides) end)
          ([], provided) analysed
      val index =
        {libraries = libs,
         scope = exports,
         header = Option.map (fn {friends, ...} => {friends = friends, views = views, virtuals = virtuals, implements = implements}) header,
         fixities = case (exports, header) of
                      (SOME es, SOME _) => List.filter (fn (n, _) => List.exists (fn e => e = ("fixity", n)) es) (List.rev ownFixity)
                    | _ => [],
         inline = inl, inlineValues = inlVals, lines = List.rev lines}
    in {index = index, read = List.rev (!reads), facts = List.rev (!factsRev)} end
    handle P.Invalid m => raise Usage m

  (* ---- the record in the store ----
     In a store's directory "index", by a name: the format, the compiler's
     identity, its hash's, the platform and the library's place, its path
     under the libraries (--lib) or else from the root of the machine's
     filesystem, so that the record a frozen layer ships holds wherever it is
     installed. It holds

       magic version string(name) at
       list(path option(stamp)) string(hashes)  what was read, its stat, and its bytes' hashes
       string(inputs)                     the hash of those paths and hashes
       list(place hash)                   the libraries it was made against
       string(hash) string(index)         the index, held to its hash

     and beside it, in a file of its own that only a making again reads,
     what each file was to it, held to its hash too. What was read and what it
     was made against need no hash of their own: a damage to them can only
     make the record a miss, since a file's stat names the file, and a hash is
     of what it holds. The index is held to its hash, which is what a library
     made against it records. The inputs' hash is what a compile that is up
     to date records of the index (UnitMemo): its damage too is a miss,
     and while the files' stats hold they are what it was made of. *)
  val magic = "RIX"
  val version = 5

  (* what was read is held as its paths with their stats, and the hashes of
     their bytes in one string, which only a file whose stat moved reads *)
  type record = {at : LargeInt.int, files : (string * S.stamp option) list, hashes : string, inputs : string,
                 against : (string * string) list, indexHash : string, index : string}
  val hashWidth = 32
  fun hashAt (hashes : string, i : int) : string = String.substring (hashes, hashWidth * i, hashWidth)
  fun recordOf (at : LargeInt.int, read : read list, against, indexHash : string, index : string) : record =
    let
      val files = List.map (fn {path, stamp, ...} => (path, stamp)) read
      val hashes = String.concat (List.map #hash read)
    in
      {at = at, files = files, hashes = hashes, inputs = hash (String.concat (List.map (fn (p, _) => p ^ "\000") files) ^ hashes),
       against = against, indexHash = indexHash, index = index}
    end

  fun windowsHere () : bool =
    List.exists (fn (key, value) => key = "sysname" andalso value = "Windows") (Posix.ProcEnv.uname ())
    handle OS.SysErr _ => false

  fun absolute (p : string) : string =
    OS.Path.mkCanonical (OS.Path.mkAbsolute {path = p, relativeTo = OS.FileSys.getDir ()})
    handle OS.SysErr _ => p | OS.Path.Path => p

  (* a library's place: its path under the libraries, or else its own; a
     directory named from the libraries' as ROOT/NAME, as a library is found,
     is NAME with no question of the filesystem *)
  fun placeOf (root : string, dir : string) : string =
    let
      val named = if String.isPrefix (root ^ "/") dir then String.extract (dir, size root + 1, NONE) else ""
      fun plain n = n <> "" andalso List.all (fn a => a <> "" andalso a <> "." andalso a <> "..")
                                             (String.fields (fn c => c = #"/") n)
    in
      if plain named then "lib:" ^ named
      else
        let val r = absolute root val d = absolute dir
        in if String.isPrefix (r ^ "/") d then "lib:" ^ String.extract (d, size r + 1, NONE) else "dir:" ^ d end
    end

  fun nameOf (place : string, windows : bool) : string =
    String.concatWith "\000" ["library-index", Int.toString version, Config.identity, Pickle.probe (),
                              if windows then "windows" else "posix", place]

  fun recordFile (store : string, name : string) : string = S.sideFile (fn (_, t) => hash t, store, "index", name)
  fun factsFile (store : string, name : string) : string = S.sideFile (fn (_, t) => hash t, store, "index", name ^ "\000facts")

  fun readRecord (p : string, name : string) : record option =
    (let
       val r = Pickle.reader (S.readFile p)
       val () = if Pickle.rbytes (r, 3) = magic andalso Pickle.rnat r = version andalso Pickle.rstring r = name then ()
                else raise Pickle.Bad "another record"
       val at = S.rlarge r
       val files = Pickle.rlist (fn r => let val path = Pickle.rstring r in (path, Pickle.roption S.rstamp r) end) r
       val hashes = Pickle.rstring r
       val () = if size hashes = hashWidth * List.length files then () else raise Pickle.Bad "not the hashes of the files"
       val inputs = Pickle.rstring r
       val against = Pickle.rlist (fn r => let val place = Pickle.rstring r in (place, Pickle.rstring r) end) r
       val indexHash = Pickle.rstring r
       val index = Pickle.rstring r
     in
       if Pickle.atEnd r
       then SOME {at = at, files = files, hashes = hashes, inputs = inputs, against = against, indexHash = indexHash,
                  index = index}
       else NONE
     end)
    handle IO.Io _ => NONE | Pickle.Bad _ => NONE | Overflow => NONE | Subscript => NONE | Size => NONE

  fun writeRecord (store : string, name : string, {at, files, hashes, inputs, against, indexHash, index} : record) : unit =
    let
      val p = recordFile (store, name)
      val w = Pickle.writer ()
      open Pickle
    in
      bytes (w, magic); nat (w, version); string (w, name); S.wlarge (w, at);
      list (fn (w, (path, stamp)) => (string (w, path); option S.wstamp (w, stamp))) (w, files);
      string (w, hashes); string (w, inputs);
      list (fn (w, (place, h)) => (string (w, place); string (w, h))) (w, against);
      string (w, indexHash); string (w, index);
      (S.mkdirs (OS.Path.dir p); S.publish (p, contents w))
      handle IO.Io _ => () | OS.SysErr _ => ()
    end

  (* what each file was to a making, by its key, held to its hash *)
  fun readFactsFile (p : string, name : string) : (string * facts) list option =
    (let
       val r = Pickle.reader (S.readFile p)
       val () = if Pickle.rbytes (r, 3) = "RIF" andalso Pickle.rnat r = version andalso Pickle.rstring r = name then ()
                else raise Pickle.Bad "another record"
       val h = Pickle.rstring r
       val bytes = Pickle.rstring r
     in
       if Pickle.atEnd r andalso hash bytes = h
       then SOME (Pickle.rlist (fn r => let val k = Pickle.rstring r in (k, readFacts r) end) (Pickle.reader bytes))
       else NONE
     end)
    handle IO.Io _ => NONE | Pickle.Bad _ => NONE | Overflow => NONE | Subscript => NONE | Size => NONE
  fun writeFactsFile (store : string, name : string, facts : (string * facts) list) : unit =
    let
      val p = factsFile (store, name)
      val b = let val w = Pickle.writer () in Pickle.list (fn (w, (k, f)) => (Pickle.string (w, k); writeFacts (w, f))) (w, facts);
                                                Pickle.contents w end
      val w = Pickle.writer ()
    in
      Pickle.bytes (w, "RIF"); Pickle.nat (w, version); Pickle.string (w, name); Pickle.string (w, hash b); Pickle.string (w, b);
      (S.mkdirs (OS.Path.dir p); S.publish (p, Pickle.contents w))
      handle IO.Io _ => () | OS.SysErr _ => ()
    end

  (* Where a compile keeps the records: the overlay of its store, which
     --cache-dir, RUNE_CACHE or its home names (UnitCache.directory), where
     it has one, then the frozen layer of its libraries, lib/cache, only
     read; a compile with --no-cache reads them and writes none *)
  fun storeDir () : string option =
    case !CompilerSettings.cacheDir of
      SOME d => SOME d
    | NONE =>
        case OS.Process.getEnv "RUNE_CACHE" of
          SOME d => if d = "" then NONE else SOME d
        | NONE => Option.map (fn home => OS.Path.joinDirFile {dir = home, file = ".rune"}) (!CompilerSettings.storeHome)
  fun overlay () : string option = if !CompilerSettings.noCache then NONE else storeDir ()
  fun stores (root : string) : string list =
    let val frozen = OS.Path.joinDirFile {dir = root, file = "cache"}
    in
      (case storeDir () of SOME d => [d] | NONE => [])
      @ (if (OS.FileSys.isDir frozen handle OS.SysErr _ => false) then [frozen] else [])
    end

  (* ---- the query ---- *)

  (* What a compile that keeps what it read keeps of an index it took
     (UnitMemo, up to date): the library's directory, that of the libraries,
     the name of the index's record and the hash of what the index rests on,
     its record's inputs -- the record, and not a copy of its files, which a
     compile asking whether it is up to date holds again (stillRests) *)
  type rests = {dir : string, root : string, name : string, inputs : string}
  (* What this compile knows: each library's index by its directory, with
     the hash of its bytes, the files it rests on (made as they are asked
     for, which an editor's analysis does) and what it rests on, and those
     being made, to refuse a library written on itself. A compile begins
     with none (forget) *)
  val known : (string * (index * string * (unit -> string list) * rests)) list ref = ref []
  val () = CompilerState.cellRoot ("LibraryIndex.known", known)
  val making : string list ref = ref []
  val () = CompilerState.cellRoot ("LibraryIndex.making", making)
  val platform : bool option ref = ref NONE
  val () = CompilerState.cellRoot ("LibraryIndex.platform", platform)
  (* And what the compiles of a session made or read, by each record's name,
     which a compile that begins does not take on trust but holds to what
     it was made of, as a record of the store: the first place a query
     looks, so that a session with no store (the compiler's API, an
     editor's analysis) makes no index twice *)
  val held : (string * record) list ref = ref []
  val () = CompilerState.cellRoot ("LibraryIndex.held", held)
  val heldFacts : (string * (string * facts) list) list ref = ref []
  val () = CompilerState.cellRoot ("LibraryIndex.heldFacts", heldFacts)
  fun hold (name : string, record : record) : unit = held := (name, record) :: List.filter (fn (n, _) => n <> name) (!held)
  fun forget () = (known := []; making := [])
  fun windows () = case !platform of SOME w => w | NONE => let val w = windowsHere () in platform := SOME w; w end
  (* And what each index taken since restFrom rests on, as it was first
     taken, as a compile keeps the stat a file had when it was first read *)
  val rested : rests list ref = ref []
  val () = CompilerState.cellRoot ("LibraryIndex.rested", rested)
  (* the indexes a compile that begins to keep what it reads knows already,
     which its plan took *)
  fun restFrom () : unit = rested := List.map (fn (_, (_, _, _, r)) => r) (!known)

  (* an index this compile knows, the files it rests on, and what it rests on *)
  fun remember (idx : index, h : string, files : (string * S.stamp option) list, r as {dir, name, ...} : rests)
      : index * string =
    (known := (dir, (idx, h, fn () => List.map (fn (path, _) => dir ^ "/" ^ path) files, r))
              :: List.filter (fn (d, _) => d <> dir) (!known);
     if List.exists (fn r' => #dir r' = dir andalso #name r' = name) (!rested) then () else rested := r :: !rested;
     (idx, h))

  (* Whether what a record was made of is what it was: each file by its
     stat, racily clean as of at, else by the hash of its bytes, read after
     its stat is taken again; SOME of what it read with the stats it has now,
     and whether one of them moved, which a record written again keeps. Where
     none moved, which is a hit's way, what it read is the record's own *)
  fun stillRead (dir : string, at : LargeInt.int, files : (string * S.stamp option) list, hashes : string)
      : ((string * S.stamp option) list * bool) option =
    let
      (* clean as of at: the later of a stamp's times two seconds before *)
      val limit = LargeInt.toInt at - 2 handle Overflow => ~1
      fun clean ({mtime, ctime, ...} : S.stamp) = Int.max (mtime, ctime) div 1000000 <= limit
      fun sameBytes (p, i) = (hash (readText p) = hashAt (hashes, i) handle IO.Io _ => false)
      val prefix = dir ^ "/"
      (* whether one moved, and the stats now of those that did, by place *)
      fun go ([], _, moved, nows) = SOME (moved, nows)
        | go ((path, stamp) :: rest, i, moved, nows) =
            let val p = prefix ^ path
                val now = S.statOf p
            in
              case (now, stamp) of
                (SOME s, SOME was) =>
                  if S.sameStamp (s, was) andalso clean s then go (rest, i + 1, moved, nows)
                  else if sameBytes (p, i) then go (rest, i + 1, true, (i, now) :: nows)
                  else NONE
              | _ => if sameBytes (p, i) then go (rest, i + 1, moved orelse isSome now, (i, now) :: nows) else NONE
            end
      fun now nows (i, (path, stamp)) = case List.find (fn (j, _) => j = i) nows of SOME (_, st) => (path, st) | NONE => (path, stamp)
    in
      case go (files, 0, false, []) of
        NONE => NONE
      | SOME (moved, []) => SOME (files, moved)
      | SOME (moved, nows) =>
          SOME (#2 (List.foldr (fn (f, (i, acc)) => (i - 1, now nows (i - 1, f) :: acc)) (List.length files, []) files), moved)
    end

  (* Whether an index a compile took rests on what it rested on then: a
     record of its name, the session's or a store's, of the same inputs,
     whose files are still what it was made of (stillRead). That is every
     file the index rests on, by its stat where that is racily clean and else
     by its bytes, as a query holds a record, though the index is not read.
     A record whose stats moved is written again with them, and one of the
     overlay has its time kept, as a query does *)
  fun stillRests ({dir, root, name, inputs} : rests) : bool =
    Pass.timed "index" (fn () =>
    let
      fun holdsNow (record : record, store : string option) : bool =
        #inputs record = inputs
        andalso
        (let val at = S.nowSeconds ()
         in
           case stillRead (dir, #at record, #files record, #hashes record) of
             NONE => false
           | SOME (filesNow, moved) =>
               (if moved
                then let val record' = {at = at, files = filesNow, hashes = #hashes record, inputs = inputs,
                                        against = #against record, indexHash = #indexHash record, index = #index record}
                     in Option.app (fn o' => writeRecord (o', name, record')) (overlay ()); hold (name, record') end
                else if isSome store andalso store = overlay () then S.touch (recordFile (valOf store, name))
                else ();
                true)
         end)
    in
      (case List.find (fn (n, _) => n = name) (!held) of SOME (_, record) => holdsNow (record, NONE) | NONE => false)
      orelse List.exists (fn store => case readRecord (recordFile (store, name), name) of
                                        SOME record => holdsNow (record, SOME store)
                                      | NONE => false)
                         (stores root)
    end)

  (* The index of the library in dir, with the hash of its bytes: what this
     compile knows, else a record that still holds, else made and kept;
     fresh, made again whatever is known *)
  fun indexWithHash {root : string, dir : string, warnings : bool, fresh : bool} : index * string =
    case (if fresh then NONE else List.find (fn (d, _) => d = dir) (!known)) of
      SOME (_, (idx, h, _, _)) => (idx, h)
    | NONE =>
        (* a stage of --pass-stats of its own, wherever a compile asks
           (Pass.timed): one inside another stage is counted there *)
        Pass.timed "index" (fn () =>
        let
          val () = if List.exists (fn d => d = dir) (!making)
                   then raise Usage ("library " ^ dir ^ " is written on itself (" ^ String.concatWith " <- " (dir :: !making) ^ ")")
                   else ()
          val w = windows ()
          val name = nameOf (placeOf (root, dir), w)
          fun within f = (making := dir :: !making; f () before making := tl (!making))
                         handle e => (making := tl (!making); raise e)
          (* what an index is made against now: each library by its place
             and the hash of its index *)
          fun againstNow (idx : index) : (string * string) list =
            within (fn () => List.map (fn d => (placeOf (root, d), #2 (indexWithHash {root = root, dir = d, warnings = false, fresh = false})))
                                      (dirsOf (root, dir, idx)))
          (* a record that holds, the session's or that of the first store
             that has one; one in memory needs no hash of its bytes *)
          fun holds (record as {files, hashes, inputs, against, indexHash, index, ...} : record, kept : bool) =
            let val at = S.nowSeconds ()
            in
              case stillRead (dir, #at record, files, hashes) of
                NONE => NONE
              | SOME (filesNow, moved) =>
                  (case (SOME (readIndex (Pickle.reader index)) handle Pickle.Bad _ => NONE | Subscript => NONE
                                                                      | Overflow => NONE | Size => NONE) of
                     SOME idx =>
                       if (kept orelse hash index = indexHash) andalso againstNow idx = against
                       then SOME ({at = at, files = filesNow, hashes = hashes, inputs = inputs, against = against,
                                   indexHash = indexHash, index = index}, idx, moved)
                       else NONE
                   | NONE => NONE)
            end
          (* a record taken from the overlay has its time kept, as an entry
             has, so that trim keeps what compiles take (UnitStore.touch) *)
          fun holding [] = NONE
            | holding (store :: rest) =
                case readRecord (recordFile (store, name), name) of
                  NONE => holding rest
                | SOME record =>
                    case holds (record, false) of
                      NONE => holding rest
                    | found => (if overlay () = SOME store then S.touch (recordFile (store, name)) else (); found)
          fun found () =
            case List.find (fn (n, _) => n = name) (!held) of
              SOME (_, record) => (case holds (record, true) of NONE => holding (stores root) | some => some)
            | NONE => holding (stores root)
        in
          case (if fresh then NONE else found ()) of
            SOME (record as {indexHash, inputs, files, ...}, idx, moved) =>
              ((* a record whose stats moved, written again with them *)
               if moved then Option.app (fn o' => writeRecord (o', name, record)) (overlay ()) else ();
               hold (name, record);
               remember (idx, indexHash, files, {dir = dir, root = root, name = name, inputs = inputs}))
          | NONE =>
              let
                (* what each file was to a making before, by its key, the
                   session's or a store's; and the hash of each file the
                   record before read, by its stat *)
                val previous =
                  case List.find (fn (n, _) => n = name) (!heldFacts) of
                    SOME (_, fs) => fs
                  | NONE => getOpt (List.foldl (fn (store, found) => case found of
                                                                     SOME _ => found
                                                                   | NONE => readFactsFile (factsFile (store, name), name))
                                               NONE (stores root), [])
                val was =
                  case List.find (fn (n, _) => n = name) (!held) of
                    SOME (_, record) => SOME record
                  | NONE => List.foldl (fn (store, found) => case found of
                                                              SOME _ => found
                                                            | NONE => readRecord (recordFile (store, name), name))
                                       NONE (stores root)
                val wasAt = case was of SOME {at, ...} => at | NONE => LargeInt.fromInt 0
                val table = List.foldl (fn ((k, f), m) => StringMap.insert (m, k, f)) StringMap.empty previous
                val stamps = case was of
                               NONE => StringMap.empty
                             | SOME {files, hashes, ...} =>
                                 #1 (List.foldl (fn ((path, SOME st), (m, i)) => (StringMap.insert (m, path, (st, hashAt (hashes, i))), i + 1)
                                                  | (_, (m, i)) => (m, i + 1)) (StringMap.empty, 0) files)
                fun hashed (p, SOME now) =
                      (case StringMap.find (stamps, p) of
                         SOME (was, h) => if S.sameStamp (was, now) andalso S.clean (now, wasAt) then SOME h else NONE
                       | NONE => NONE)
                  | hashed (_, NONE) = NONE
                val at = S.nowSeconds ()
                val {index = idx, read, facts} =
                  within (fn () =>
                    make {dir = dir, root = root, warnings = warnings, windows = w,
                          index = fn d => #1 (indexWithHash {root = root, dir = d, warnings = false, fresh = false}),
                          known = fn k => StringMap.find (table, k), hashed = hashed})
                val bytes = let val wr = Pickle.writer () in writeIndex (wr, idx); Pickle.contents wr end
                val indexHash = hash bytes
                val against = againstNow idx
                val record = recordOf (at, read, against, indexHash, bytes)
              in
                Option.app (fn o' => (writeRecord (o', name, record); writeFactsFile (o', name, facts))) (overlay ());
                hold (name, record);
                heldFacts := (name, facts) :: List.filter (fn (n, _) => n <> name) (!heldFacts);
                remember (idx, indexHash, #files record,
                          {dir = dir, root = root, name = name, inputs = #inputs record})
              end
        end)
  (* the libraries an index is made against: the Basis Library, but for
     itself, and the libraries it is written on, with theirs, in order *)
  and dirsOf (root : string, dir : string, idx : index) : string list =
    let val basis = root ^ "/basis"
    in
      if OS.Path.mkCanonical dir = OS.Path.mkCanonical basis then []
      else (if hasBasis root then [basis] else []) @ (case #libraries idx of [] => [] | libs => librariesOf root libs)
    end
  and indexOf (root : string) (dir : string) : index = #1 (indexWithHash {root = root, dir = dir, warnings = false, fresh = false})
  and librariesOf (root : string) (names : string list) : string list =
    let
      fun requires d = #libraries (indexOf root d)
      fun virtuals d = case #header (indexOf root d) of SOME {virtuals, ...} => virtuals | NONE => []
      fun implements d = case #header (indexOf root d) of SOME {implements, ...} => implements | NONE => []
    in B.librariesWith {requires = requires, virtuals = virtuals, implements = implements} (root, names) end

  (* ---- what the readers ask ---- *)

  (* the index of the library in dir, root being the directory of the
     libraries (--lib) *)
  fun index {root : string, dir : string} : index = indexOf root dir
  (* its entries, as a compile chooses among them *)
  fun entries {root : string, dir : string} : entry list = B.entriesOf (dir, indexOf root dir)
  (* the directories of the named libraries and of those they are written
     on, in the order they are compiled (BasisManifest.librariesWith) *)
  fun libraries (_ : string, [] : string list) : string list = []
    | libraries (root, names) = librariesOf root names
  (* what each scope of a compile sees (BasisManifest.scopes) *)
  fun scopes {root : string, building : string option, names : string list, headed : bool,
              libraries : (string * entry list) list, view : string option} : B.scopes =
    B.scopes {root = root, building = building, names = names, headed = headed, libraries = libraries, view = view,
              requires = #libraries o indexOf root}
  (* the fixity a library exports, for reading the files of one that
     requires it, and the functors and functions it marks to inline *)
  fun fixities {root : string, dir : string} = #fixities (indexOf root dir)
  fun inlineFunctors {root : string, dir : string} = #inline (indexOf root dir)
  fun inlineValues {root : string, dir : string} = #inlineValues (indexOf root dir)
  (* every file an index rests on, from its library's directory: its
     build files and its sources (what an editor watches) *)
  fun inputs {root : string, dir : string} : string list =
    (ignore (indexOf root dir);
     case List.find (fn (d, _) => d = dir) (!known) of SOME (_, (_, _, paths, _)) => paths () | NONE => [])

  (* --basis-index DIR: the index made again, with what a client cannot act
     on said, and its text *)
  fun check {root : string, dir : string, warnings : bool} : string =
    text (#1 (indexWithHash {root = root, dir = dir, warnings = warnings, fresh = true}))
end

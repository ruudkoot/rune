(* A library's index: DIR/MANIFEST, what each file of the library provides
   and requires (BasisManifest), from its build file DIR/library.build, read
   as any build file is (CompilerProject) -- each file's class and host by
   its annotations ("always", "demand", "seal", "final"; "host=swap",
   "host=no"), the libraries it is written on by `requires` or `libraries`
   -- and from the files: what each declares (Deps), and what it uses that the
   files before it, the Basis Library or the libraries it is written on
   provide. A file that uses a name only a file after it provides is refused.
   Both the driver and runedoc reach this (D13). *)
structure LibraryIndex =
struct
  structure P = CompilerProject
  type entry = BasisManifest.entry
  exception Usage = BasisManifest.Usage

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

  fun loadTokens (path : string) : Lexer.item vector =
    Lexer.tokenize (Source.load (Source.Ascii, path))
    handle IO.Io _ => raise Usage ("cannot read " ^ path)

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

  fun write {dir : string, root : string, warnings : bool, windows : bool} : unit =
    let
      val file = OS.Path.joinDirFile {dir = dir, file = "library.build"}
      val libDir = root ^ "/basis"
      fun read path =
        {text = readText path handle IO.Io _ => raise P.Invalid ("cannot read the build file " ^ path), revision = ""}
      val plan = P.planWith {file = file, windows = windows, readBuild = read, hosts = true} handle P.Invalid m => raise Usage m
      val here = P.directory windows (P.normalize windows file)
      (* a path of the plan, from the library's directory *)
      fun relative p =
        OS.Path.mkCanonical (if here <> "" andalso String.isPrefix (here ^ "/") p then String.extract (p, size here + 1, NONE) else p)
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
               else List.app (fn l => if List.null (#renames (BasisManifest.importOf l)) then ()
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
         provide, from their MANIFESTs, made before this one's *)
      val isBasis = OS.Path.mkCanonical dir = OS.Path.mkCanonical libDir
      val written = if isBasis then []
                    else List.map (fn d => (d, BasisManifest.readManifest d)) (BasisManifest.libraries (root, libs))
      val () = if isBasis orelse isSome header orelse not warnings then ()
               else (Error.warn ({file = file, start = 0, stop = 0},
                                 "this library has no header: all it declares is public, and its libraries are transitive (docs/build.md, A library's header)");
                     Error.flushWarnings ())
      val outside = if isBasis then [] else BasisManifest.readManifest libDir @ List.concat (List.map #2 written)
      (* with a header, it sees the Basis Library and what it requires alone,
         through what a client of it would (BasisManifest) *)
      val scopes = BasisManifest.scopes {root = root, building = SOME file, names = libs, headed = isSome header, libraries = written,
                                         view = NONE}
      fun usable (e : entry) =
        if not (isSome header) orelse #dir e = libDir then BasisManifest.public e
        else BasisManifest.seenNames (#program scopes, e)
      (* two imports of one name in its scope (D9) *)
      val () = if not (isSome header) then ()
               else case BasisManifest.clashes (#program scopes, outside, libDir) of
                      [] => ()
                    | clash :: _ => raise Usage (file ^ ": " ^ clashText root clash)
      val provided = List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (usable e))
                                StringMap.empty outside
      (* and what of those a boundary, or not being required, hides *)
      val hidden = List.foldl (fn (e : entry, m) =>
                                 let val public = BasisManifest.public e
                                 in List.foldl (fn (n, m) =>
                                      if StringMap.member (provided, n) then m
                                      else StringMap.insert (m, n, (#dir e, List.exists (fn p => p = n) public))) m (#provides e) end)
                              StringMap.empty outside
      (* The fixity a file of the library is read in: the initial basis's, what
         it requires exports, and what its files before say; a file may be in
         a directory below the library's: sized/int32.sml *)
      val imported = List.concat (List.map BasisManifest.fixities
                                           (if isSome header then List.map #dir (#program scopes) else List.map #1 written))
      (* each file's virtual modules and _export declarations, and how many
         times it says _virtual *)
      val dynamics = ref [] : (string * string list * {virtuals : (string * string) list, exports : (string * string) list} * int) list ref
      val (analysedRev, afterAll) =
        List.foldl (fn ((p, anns), (acc, fx)) =>
                      let val toks = loadTokens (OS.Path.concat (dir, p))
                          val (prog, fx') = Parser.parseTokensWith (toks, fx)
                      in dynamics := (p, anns, dynamicModules prog, virtualTokens toks) :: !dynamics;
                         ((p, anns, Deps.analyse (p, prog)) :: acc, fx') end)
                   ([], Fixity.extend (Fixity.initial, imported)) listed
      val analysed = List.rev analysedRev
      val dynamics = List.filter (fn (_, anns, _, _) => hostOf anns <> "only") (List.rev (!dynamics))
      (* the rules (docs/units.md, Well-formed units), of the files Rune
         compiles: a strict library is held to them, and another is told of
         them once *)
      val () =
        case (Deps.illFormed (List.mapPartial (fn (_, anns, f) => if hostOf anns = "only" then NONE
                                                                  else SOME (Deps.unitOf (true, anns, f))) analysed),
              header) of
          ([], _) => ()
        | (findings, SOME {strict = true, ...}) =>
            (List.app (fn (sp, what) => TextIO.output (TextIO.stdErr, Error.format (sp, Deps.notWellFormed what) ^ "\n")) findings;
             raise Usage (file ^ ": a strict library's units are well-formed, and "
                          ^ (case findings of [_] => "one is not" | _ => Int.toString (List.length findings) ^ " are not")))
        | ((sp, what) :: rest, _) =>
            if not warnings then ()
            else (Error.warn ({file = file, start = 0, stop = 0},
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
      fun exportWords es = String.concatWith " " (List.map (fn (k,n) => k ^ ":" ^ n) es)
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
      val () =
        case List.find (fn (_, _, {virtuals = vs, ...}, _) => not (List.null vs)) dynamics of
          NONE => ()
        | SOME (first, _, _, _) =>
            let
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
            val direct = List.map (fn l => BasisManifest.libraryDir (root, l)) libs
            fun virtualIn (d, es) = case es of (e : entry) :: _ => List.map (fn m => (m, d, es)) (BasisManifest.virtualsOf e) | [] => []
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
            val (_, tail) = BasisManifest.virtualTail (BasisManifest.virtualsOf (hd entries), entries)
            val late = List.concat (List.map #provides tail)
          in
            List.app (fn (p, _, f : Deps.file) =>
                        case List.find (fn (_, n) => List.exists (fn l => l = n) late) (#uses f) of
                          SOME (_, n) => refuse (p ^ " uses " ^ n ^ ", which " ^ libraryShown (root, owner)
                                                 ^ " declares from its first virtual module on, after its implementation")
                        | NONE => ()) analysed
          end
      val scopeColumn = case (exports, header) of (NONE, _) => "" | (_, SOME _) => "" | (SOME [], _) => " | -"
        | (SOME es, _) => " | " ^ exportWords es
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
               val line = p ^ " | " ^ classOf anns ^ " | " ^ hostOf anns ^ " | " ^ String.concatWith " " provides ^ " | "
                          ^ String.concatWith " " requires ^ scopeColumn
             in (line :: acc, List.foldl (fn (n, m) => StringMap.insert (m, n, ())) earlier provides) end)
          ([], provided) analysed
      val out = OS.Path.joinDirFile {dir = dir, file = "MANIFEST"}
      (* in bytes, so that every host writes the same file (Emit.writeFileAs) *)
      val o' = BinIO.openOut out
      fun put s = BinIO.output (o', Byte.stringToBytes s)
    in
      put "# Generated from library.build by rune --basis-index -- do not edit.\n";
      List.app (fn l => put ("# library: " ^ l ^ "\n")) libs;
      (case (exports, header) of
         (SOME es, SOME {friends, ...}) =>
           (put ("# exports: " ^ (if List.null es then "-" else exportWords es) ^ "\n");
            if List.null virtuals then () else put ("# virtual: " ^ exportWords virtuals ^ "\n");
            if List.null implements then () else put ("# implements: " ^ exportWords implements ^ "\n");
            if List.null friends then () else put ("# friends: " ^ String.concatWith " " friends ^ "\n");
            List.app (fn (v, es) => put ("# view: " ^ v ^ " " ^ exportWords es ^ "\n")) views;
            List.app (fn (n, f) => put ("# fixity: " ^ (case f of Fixity.Infix p => "infix " ^ Int.toString p
                                                                | Fixity.Infixr p => "infixr " ^ Int.toString p
                                                                | Fixity.Nonfix => "nonfix") ^ " " ^ n ^ "\n"))
                     (List.filter (fn (n, _) => List.exists (fn e => e = ("fixity", n)) es) (List.rev ownFixity)))
       | _ => ());
      if List.null inl then () else put ("# inline: " ^ String.concatWith " " inl ^ "\n");
      if List.null inlVals then () else put ("# inline val: " ^ String.concatWith " " inlVals ^ "\n");
      List.app (fn l => put (l ^ "\n")) (List.rev lines);
      BinIO.closeOut o'
    end
end


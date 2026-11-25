(* The modules of a program (the haskell98 roadmap's M12, D30): found by
   scanning imports from the files rhc is given, each read once, and taken
   in their strongly connected groups, the modules a group imports before
   it. rhc does not use the compiler's Deps, which refuses a cycle
   (lib/compiler/driver/deps.sml); a cycle here is one group, a unit.

   Where a module is (5.7 leaves it to the implementation): a program's
   module `M` is the file M.hs or M.lhs beside the first file given, and
   failing that the library's (RhcLibrary), whose own imports are of the
   library alone. A module's identity is its name in a program and
   `haskell98:` and its name in the library, so a program's `Char` is not
   the library's, and a program's `Prelude` is the one its modules
   import. Every module but one named Prelude imports the Prelude unless
   it imports it itself (5.6.1); the Prelude does not import itself (D29). A
   program cannot import the modules RhcLibrary hides (D36). A module
   whose language has HierarchicalModules (--dotted-names, D35; Haskell
   2010) finds the module `A.B` it imports in the file A/B.hs.

   Each module has a language (HsLanguage; the haskell2010 roadmap's D4 to
   D10): the library's is its descriptor's, whatever the program's; a
   program's is the setting of the command line with its header's
   LANGUAGE pragmas after it (HsHeader, read from its text before it is
   lexed), and it decides how the module is lexed and parsed, where the
   modules it imports are looked for, and how it is checked. *)
structure RhcGraph =
struct
  structure A = HsAst
  structure M = HsStringMap

  (* A module as read: its identity, its name, its file, whether it is
     the library's, its language, its tree, and its imports with the
     identity of each module they name, the implicit import of the Prelude
     among them. *)
  type node = {id : string, name : string, file : string, library : bool, language : HsLanguage.t, ast : A.module,
               imports : (A.import * string) list}

  (* A diagnostic, and whether it is of a module of the library. *)
  type diag = {span : HsSource.span, msg : string, library : bool}

  (* The program's modules by group, dependencies first, and the
     diagnostics of finding them. *)
  type graph = {groups : node list list, roots : string list, diags : diag list}

  (* every file read, for its diagnostics' lines and columns *)
  val texts : HsSource.text M.map ref = ref M.empty

  fun textOf file = M.find (!texts, file)

  fun nameOf (A.Name (_, {name, ...})) = name

  fun readBytes path =
    let val f = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll f) before BinIO.closeIn f end

  fun exists path = OS.FileSys.access (path, [OS.FileSys.A_READ]) andalso not (OS.FileSys.isDir path)
    handle OS.SysErr _ => false

  (* the file of module `m` in `dir`, if there is one *)
  fun fileIn (dir, m, dotted) =
    let
      val parts = if dotted then String.fields (fn c => c = #".") m else [m]
      val base = List.foldl (fn (p, d) => OS.Path.concat (d, p)) dir parts
      val candidates = [base ^ ".hs", base ^ ".lhs"]
    in
      List.find exists candidates
    end

  fun moduleName (A.Module (_, {name, ...})) = case name of SOME n => nameOf n | NONE => "Main"

  fun headerSpan (A.Module ({span, ...}, {name, ...})) =
    case name of SOME (A.Name ({span = s, ...}, _)) => s | NONE => {file = #file span, start = 0, stop = 0}

  (* A module without a header is `module Main (main) where` (5.1), its
     assumed export at the start of its own file, where a diagnostic of it
     is said, not at the file rhc was given *)
  fun withHeader (m as A.Module (a as {span = {file, ...}, ...}, {name, exports, imports, decls})) =
    case name of
      SOME _ => m
    | NONE =>
        let val at : A.ann = {span = {file = file, start = 0, stop = 0}, toks = []}
        in
          A.Module (a, {name = NONE, imports = imports, decls = decls,
                        exports = SOME [A.Ent (at, A.EntVar (A.Name (at, {qual = "", name = "main"})))]})
        end

  fun implicitPrelude () =
    A.Import (A.noAnn, {qualified = false, module = A.Name (A.noAnn, {qual = "", name = "Prelude"}), as_ = NONE,
                        hiding = false, spec = NONE})

  fun member (x, xs) = List.exists (fn y => y = x) xs

  (* `xs` in order of `key`, by insertion: the lists here are short *)
  fun sortBy key xs =
    let
      fun insert (x, []) = [x]
        | insert (x, y :: ys) = if String.< (key x, key y) then x :: y :: ys else y :: insert (x, ys)
    in
      List.foldl insert [] xs
    end

  (* The library's groups in an order of their own, whatever a program
     reached them by: of the groups whose imports are all taken, the one
     whose least identity is least first, its modules in order of
     identity. Of a set of the library's modules that holds what they
     import, this is the order the whole library's groups give it, so that
     a program checks and desugars its modules of the library alike whether
     they were read now or taken from bin/rhc's snapshot, which holds the
     whole library's units (RhcDriver). A
     member is known by its identity and the identities its imports name. *)
  fun canonical (id : 'a -> string, targets : 'a -> string list) (groups : 'a list list) : 'a list list =
    let
      val sorted = List.map (sortBy id) groups

      fun imports g = List.concat (List.map targets g)
      fun go ([], _, acc) = List.rev acc
        | go (pending, taken, acc) =
            let
              val pendingIds = List.concat (List.map (List.map id) pending)
              val own = fn g => List.map id g
              fun ready g =
                List.all (fn d => member (d, taken) orelse member (d, own g) orelse not (member (d, pendingIds))) (imports g)
              val first =
                List.foldl (fn (g, NONE) => if ready g then SOME g else NONE
                             | (g, SOME b) => if ready g andalso String.< (id (hd g), id (hd b)) then SOME g else SOME b)
                  NONE pending
            in
              case first of
                SOME g => go (List.filter (fn h => id (hd h) <> id (hd g)) pending, own g @ taken, g :: acc)
              | NONE => List.rev acc @ pending       (* no group is ready: a cycle among groups, which Tarjan's leave none of *)
            end
    in
      go (sorted, [], [])
    end

  (* whether a module of the language `t` reads and finds dotted names *)
  fun hierarchical t = HsLanguage.has (t, HsLanguage.HierarchicalModules)

  (* `keyed (what, k)` is a way of reading, `what`, with a language's
     text `k` after it where there is one *)
  fun keyed (what, k) = if k = "" then what else what ^ " " ^ k

  (* the files of the library's modules, by module name: its sources'
     (RhcLibrary.sources), a module's first file the one, all in order of
     their names, wherever each is *)
  fun libraryFiles () : (string * string) list =
    let
      fun inDir ((d, takes), acc) =
        let
          val s = OS.FileSys.openDir d
          fun add (base, f, acc) =
            if not (takes base) orelse List.exists (fn (m, _) => m = base) acc then acc
            else (base, OS.Path.concat (d, f)) :: acc
          fun loop acc =
            case OS.FileSys.readDir s of
              NONE => acc
            | SOME f =>
                (case OS.Path.splitBaseExt f of
                   {base, ext = SOME "hs"} => loop (add (base, f, acc))
                 | {base, ext = SOME "lhs"} => loop (add (base, f, acc))
                 | _ => loop acc)
        in
          loop acc before OS.FileSys.closeDir s
        end
        handle OS.SysErr _ => acc
    in
      sortBy #1 (List.foldl inDir [] (RhcLibrary.sources ()))
    end

  (* f's value, made once and where it is first asked for *)
  fun once (f : unit -> 'a) : unit -> 'a =
    let val cell = ref NONE
    in fn () => case !cell of SOME v => v | NONE => let val v = f () in cell := SOME v; v end end

  (* What the graph reads of a module's tree: its name and where its header
     says it, and the module each of its imports names, and where (the
     library's import of PreludeBuiltin among them, the Prelude's implicit
     one not): a function of the module's text and how it is read, which a
     reader may keep, so that a module whose unit is taken is never parsed
     (M21's warm path) *)
  type header = {name : string, at : HsSource.span, imports : (string * HsSource.span) list, pragmas : HsHeader.name list}

  (* and the names its LANGUAGE pragmas write (HsHeader), from which its
     language is resolved again where its header is kept *)
  fun headerOf (ast as A.Module (_, {imports, ...}) : A.module, pragmas : HsHeader.name list) : header =
    {name = moduleName ast, at = headerSpan ast,
     imports = List.map (fn A.Import ({span, ...}, {module = m, ...}) => (nameOf m, span)) imports, pragmas = pragmas}

  (* How a module's text is read (its `mode`: the library's, normalised,
     under its language; a program's, under the setting of the command
     line; either literate), and what a reader gives of a module: its
     text's hash, given the text where it asks for it, and the header it
     keeps of a text by its hash, if it keeps one *)
  (* What a module's reading asks of a reader: its text's hash, and the
     header kept of a text, by the name it is read for (an import's, or ""
     for a file rhc is given), the way it is read and the text's hash, not
     by its file: a header kept of one copy of a text is any copy's, its
     spans the file's that is read (bin/rhc's snapshot, made where rhc is
     built, read where it is installed) *)
  type reader = {hash : {file : string, mode : string, text : unit -> string} -> string,
                 header : {file : string, name : string, mode : string, hash : string} -> header option,
                 keep : {file : string, name : string, mode : string, hash : string} * header -> unit}

  (* the reader that keeps nothing, each module parsed as it is found *)
  val parsing : reader = {hash = fn _ => "", header = fn _ => NONE, keep = fn _ => ()}

  (* A module as found: its identity, its file, whether it is the library's,
     its text's hash (the reader's), the identities its imports name, its
     node, its tree parsed where the node is first asked for, and whether
     it has been. *)
  type found = {id : string, file : string, library : bool, language : HsLanguage.t, hash : string, imports : string list,
                node : unit -> node, parsed : unit -> bool}

  (* The program's modules as found, by group, dependencies first, and the
     diagnostics of finding them. *)
  type plan = {groups : found list list, roots : string list, diags : diag list}

  (* `scan {roots, setting, known, library, reader}` finds the program whose
     files are `roots`, the first of them beside the program's other
     modules, or with `library` every module of the library and no
     program, each module's imports from the header `reader` keeps of its
     text, its tree parsed only where it keeps none or where the module's
     node is asked for; a program's module under `setting` and its own
     header's pragmas. A module whose identity `known` has is not read
     again: it is in no group of this graph, its group taken before.

     Raises: `HsSource.Error` for a file that does not lex or parse, or
     whose header asks for a language rhc does not have, which stops rhc. *)
  (* each module read so far, the library's in a saved world among them:
     the modules its imports name, the Prelude's implicit one with them *)
  val importsOf : string list M.map ref = ref M.empty

  (* `reaches (m, n)`: whether a chain of imports leads from the module
     `m` to `n`, `m` itself among those it reaches (5.4: an instance is in
     scope where one does, R26); a module never read reaches itself alone.
     A search breadth first from `m` that stops at `n`, each answer kept by
     `M\tN`: the Prelude or a module `m` imports is found at once, and not
     after all `m` reaches, which made a module at the end of a chain of n
     cost as n (build-cache-issues.md, issue 39) *)
  val closures : bool M.map ref = ref M.empty
  fun reaches (m : string, n : string) : bool =
    m = n orelse
    (case M.find (!closures, m ^ "\t" ^ n) of
       SOME b => b
     | NONE =>
         let
           fun go ([], [], _) = false
             | go ([], later, seen) = go (List.rev later, [], seen)
             | go (x :: rest, later, seen) =
                 if x = n then true
                 else if M.member (seen, x) then go (rest, later, seen)
                 else go (rest, List.revAppend (getOpt (M.find (!importsOf, x), []), later), M.insert (seen, x, ()))
           val b = go ([m], [], M.empty)
         in
           closures := M.insert (!closures, m ^ "\t" ^ n, b); b
         end)

  fun scan {roots : string list, setting : HsLanguage.setting, known : node M.map, library : bool, reader : reader} : plan =
    let
      val founds : found M.map ref = ref M.empty
      val order : string list ref = ref []
      val diags : diag list ref = ref []
      val progDir = case roots of r :: _ => (case OS.Path.dir r of "" => "." | d => d) | [] => "."
      fun diag (library, span, msg) = diags := {span = span, msg = msg, library = library} :: !diags

      fun parse (file, library, language, raw) =
        let
          val bytes = if library then RhcLibrary.normalise raw else raw
          val () = texts := M.insert (!texts, file, HsSource.text {file = file, bytes = bytes})
          val opts : HsParser.options = {lexer = {language = language}, annotations = HsParser.Full}
          val ast = HsParser.parseFile (opts, file, bytes)
        in
          if library then RhcLibrary.primitives (ast, RhcLibrary.mentionsElided bytes) else withHeader ast
        end

      (* a module's file read: its header, the reader's or its tree's, its
         text's hash, its tree, parsed where first asked for, and its
         language: the library's, or the setting's with its header's
         pragmas, which the header keeps, so that a module whose header is
         kept is not read for them *)
      fun read (file, library, name) : header * string * (unit -> A.module) * bool ref * HsLanguage.t =
        let
          val text = once (fn () => readBytes file)
          (* a literate file's text is another program than the same text
             read plain (build-cache-issues.md, issue 27); and a program's
             is read under the command line's setting, its pragmas being
             of its text *)
          val mode = (if library then keyed ("library", HsLanguage.key (RhcLibrary.language ()))
                      else keyed ("program", HsLanguage.settingKey setting))
                     ^ (if HsLiterate.isLiterate file then " literate" else "")
          val hash = #hash reader {file = file, mode = mode, text = text}
          val parsed = ref false
          val kept = #header reader {file = file, name = name, mode = mode, hash = hash}
          (* the program text, a literate file's unlit; one that does not
             unlit has no pragmas, so that its parse says where *)
          fun program () = if HsLiterate.isLiterate file then HsLiterate.unlit (file, text ()) else text ()
          val pragmas =
            case kept of
              SOME h => #pragmas h
            | NONE => if library then [] else (HsHeader.languages (program ()) handle HsSource.Error _ => [])
          val language =
            if library then RhcLibrary.language ()
            else
              HsLanguage.ofHeader (setting, pragmas)
              handle HsLanguage.Refused (at, msg) =>
                (texts := M.insert (!texts, file, HsSource.text {file = file, bytes = text ()});
                 raise HsSource.Error ({file = file, start = at, stop = at}, msg))
          val tree = once (fn () => (parsed := true; parse (file, library, language, text ())))
          val header =
            case kept of
              SOME h => h
            | NONE =>
                let val h = headerOf (tree (), pragmas)
                in #keep reader ({file = file, name = name, mode = mode, hash = hash}, h); h end
        in
          (header, hash, tree, parsed, language)
        end

      (* the identity and the file of the module an import names, where
         the language of the module that imports it looks *)
      fun target (fromLibrary, language, mn, span) : (string * string option) option =
        let
          fun library () =
            case List.foldl (fn (_, SOME f) => SOME f
                              | ((d, takes), NONE) =>
                                  if takes mn then fileIn (d, mn, hierarchical (RhcLibrary.language ())) else NONE)
                   NONE (RhcLibrary.sources ()) of
              SOME f => SOME (RhcLibrary.identity mn, SOME f)
            | NONE => if RhcLibrary.isLeaf mn then SOME (RhcLibrary.identity mn, NONE) else NONE
          fun hidden () =
            (diag (fromLibrary, span,
                   "the module `" ^ mn ^ "` cannot be imported: it is a part of rhc's library that a program does not " ^
                   "see (the Report's chapter 8)");
             NONE)
          fun missing () =
            (diag (fromLibrary, span,
                   "no module `" ^ mn ^ "`: no file " ^ mn ^ ".hs or " ^ mn ^ ".lhs in " ^ progDir ^
                   (case RhcLibrary.sources () of
                      _ :: _ => ", and the library has none"
                    | [] => ", and rhc is not given its library (--share DIR)"));
             NONE)
        in
          if fromLibrary then (case library () of SOME t => SOME t | NONE => missing ())
          else
            case fileIn (progDir, mn, hierarchical language) of
              SOME f => SOME (mn, SOME f)
            | NONE =>
                case library () of
                  SOME t => if RhcLibrary.isHidden mn then hidden () else SOME t
                | NONE => missing ()
        end

      (* where the Prelude's implicit import is *)
      val implicitAt = let val A.Import ({span, ...}, _) = implicitPrelude () in span end

      fun visit (id, file, library, expected) =
        if M.member (!founds, id) orelse M.member (known, id) then ()
        else add (id, file, library, expected, read (file, library, getOpt (expected, "")))

      and add (id, file, library, expected, ({name, at, imports = explicit, ...} : header, hash, tree, parsed, language)) =
        let
          val () =
            case expected of
              SOME m =>
                if m = name then ()
                else diag (library, at,
                           "the file " ^ file ^ " holds the module `" ^ name ^ "`, and it is read for an import of `" ^ m ^ "`")
            | NONE => ()
          val implicit = not (name = "Prelude" orelse List.exists (fn (m, _) => m = "Prelude") explicit)
          val all = if implicit then explicit @ [("Prelude", implicitAt)] else explicit
          val targets = List.map (fn (m, span) => target (library, language, m, span)) all
          (* the node, its imports the tree's, each with its target *)
          fun node () =
            let
              val ast as A.Module (_, {imports = written, ...}) = tree ()
              val withPrelude = if implicit then written @ [implicitPrelude ()] else written
              val imports =
                ListPair.foldrEq (fn (i, SOME (t, _), acc) => (i, t) :: acc | (_, NONE, acc) => acc) [] (withPrelude, targets)
                handle ListPair.UnequalLengths => raise Fail ("RhcGraph: the header kept of " ^ file ^ " is not its tree's")
            in
              {id = id, name = name, file = file, library = library, language = language, ast = ast, imports = imports}
            end
          val f = {id = id, file = file, library = library, language = language, hash = hash,
                   imports = List.mapPartial (Option.map #1) targets, node = once node, parsed = fn () => !parsed}
        in
          founds := M.insert (!founds, id, f);
          (* its imports, beside every module's read before, for `reaches` *)
          importsOf := M.insert (!importsOf, id, #imports f);
          closures := M.empty;
          order := id :: !order;
          List.app
            (fn ((m, _), SOME (t, SOME file)) =>
                  visit (t, file, library orelse RhcLibrary.isLibrary t, SOME m)
              | _ => ())
            (ListPair.zip (all, targets))
        end

      val () =
        if library then List.app (fn (m, f) => visit (RhcLibrary.identity m, f, true, SOME m)) (libraryFiles ())
        else ()

      val rootIds =
        List.map
          (fn file =>
             let
               val r as ({name = id, ...}, _, _, _, _) = read (file, false, "")
             in
               if M.member (!founds, id) then () else add (id, file, false, NONE, r);
               id
             end)
          (if library then [] else roots)

      (* Tarjan's algorithm: a group is complete once its root is *)
      val index : int M.map ref = ref M.empty
      val low : int M.map ref = ref M.empty
      val onStack : bool M.map ref = ref M.empty
      val stack : string list ref = ref []
      val counter = ref 0
      val groups : found list list ref = ref []
      fun get (m, k) = valOf (M.find (!m, k))
      fun connect v =
        let
          val () = (index := M.insert (!index, v, !counter); low := M.insert (!low, v, !counter);
                    counter := !counter + 1; stack := v :: !stack; onStack := M.insert (!onStack, v, true))
          val {imports, ...} : found = get (founds, v)
          fun edge w =
            if not (M.member (!founds, w)) then ()
            else if not (M.member (!index, w)) then
              (connect w; low := M.insert (!low, v, Int.min (get (low, v), get (low, w))))
            else if M.find (!onStack, w) = SOME true then
              low := M.insert (!low, v, Int.min (get (low, v), get (index, w)))
            else ()
          val () = List.app edge imports
        in
          if get (low, v) = get (index, v) then
            let
              fun pop acc =
                case !stack of
                  w :: rest =>
                    (stack := rest; onStack := M.insert (!onStack, w, false);
                     if w = v then w :: acc else pop (w :: acc))
                | [] => acc
              val members = pop []
              val inOrder = List.filter (fn id => List.exists (fn m => m = id) members) (List.rev (!order))
            in
              groups := List.map (fn id => get (founds, id)) inOrder :: !groups
            end
          else ()
        end
      val () = List.app (fn v => if M.member (!index, v) then () else connect v) (List.rev (!order))
      (* the library's groups first, in their own order, then the program's *)
      val (ofLibrary, ofProgram) = List.partition (fn g => List.all #library g) (List.rev (!groups))
    in
      {groups = canonical (#id : found -> string, #imports) ofLibrary @ ofProgram, roots = rootIds,
       diags = List.rev (!diags)}
    end

  (* `loadFrom {roots, setting, known, library}` reads the program whose
     files are `roots`, the first of them beside the program's other
     modules, or with `library` every module of the library and no
     program: `scan`'s, every module parsed as it is found.

     Raises: `HsSource.Error` for a file that does not lex or parse, which
     stops rhc. *)
  fun loadFrom {roots : string list, setting : HsLanguage.setting, known : node M.map, library : bool} : graph =
    let val {groups, roots, diags} = scan {roots = roots, setting = setting, known = known, library = library, reader = parsing}
    in {groups = List.map (List.map (fn (f : found) => #node f ())) groups, roots = roots, diags = diags} end

  (* `load {roots, setting}` reads the program whose files are `roots`, the
     first of them beside the program's other modules, and the modules of
     the library it imports.

     Raises: `HsSource.Error` for a file that does not lex or parse, which
     stops rhc. *)
  fun load {roots, setting} = loadFrom {roots = roots, setting = setting, known = M.empty, library = false}
end

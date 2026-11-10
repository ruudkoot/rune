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
   program cannot import the modules RhcLibrary hides (D36). With
   `dotted`, a module `A.B` is the file A/B.hs (D35). *)
structure RhcGraph =
struct
  structure A = HsAst
  structure M = HsStringMap

  (* A module as read: its identity, its name, its file, whether it is
     the library's, its tree, and its imports with the identity of each
     module they name, the implicit import of the Prelude among them. *)
  type node = {id : string, name : string, file : string, library : bool, ast : A.module,
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

  (* A module without a header is `module Main (main) where` (5.1). *)
  fun withHeader (m as A.Module (a, {name, exports, imports, decls})) =
    case name of
      SOME _ => m
    | NONE =>
        A.Module (a, {name = NONE, imports = imports, decls = decls,
                      exports = SOME [A.Ent (A.noAnn, A.EntVar (A.Name (A.noAnn, {qual = "", name = "main"})))]})

  fun implicitPrelude () =
    A.Import (A.noAnn, {qualified = false, module = A.Name (A.noAnn, {qual = "", name = "Prelude"}), as_ = NONE,
                        hiding = false, spec = NONE})

  (* `load {roots, dotted}` reads the program whose files are `roots`, the
     first of them beside the program's other modules.

     Raises: `HsSource.Error` for a file that does not lex or parse, which
     stops rhc. *)
  fun load {roots : string list, dotted : bool} : graph =
    let
      val nodes : node M.map ref = ref M.empty
      val order : string list ref = ref []
      val diags : diag list ref = ref []
      val progDir = case roots of r :: _ => (case OS.Path.dir r of "" => "." | d => d) | [] => "."
      fun diag (library, span, msg) = diags := {span = span, msg = msg, library = library} :: !diags

      fun parse (file, library) =
        let
          val raw = readBytes file
          val bytes = if library then RhcLibrary.normalise raw else raw
          val () = texts := M.insert (!texts, file, HsSource.text {file = file, bytes = bytes})
          val opts : HsParser.options = {lexer = {hierarchical = dotted andalso not library}, annotations = HsParser.Full}
          val ast = HsParser.parseFile (opts, file, bytes)
        in
          if library then RhcLibrary.primitives (ast, RhcLibrary.mentionsElided bytes) else withHeader ast
        end

      (* the identity and the file of the module an import names *)
      fun target (fromLibrary, A.Import ({span, ...}, {module = m, ...})) : (string * string option) option =
        let
          val mn = nameOf m
          fun library () =
            case Option.mapPartial (fn d => fileIn (d, mn, false)) (RhcLibrary.dir ()) of
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
                   (case RhcLibrary.dir () of
                      SOME _ => ", and the library has none"
                    | NONE => ", and rhc is not given its library (--share DIR)"));
             NONE)
        in
          if fromLibrary then (case library () of SOME t => SOME t | NONE => missing ())
          else
            case fileIn (progDir, mn, dotted) of
              SOME f => SOME (mn, SOME f)
            | NONE =>
                case library () of
                  SOME t => if RhcLibrary.isHidden mn then hidden () else SOME t
                | NONE => missing ()
        end

      fun visit (id, file, library, expected) =
        if M.member (!nodes, id) then () else add (id, file, library, expected, parse (file, library))

      and add (id, file, library, expected, ast) =
        let
          val name = moduleName ast
          val () =
            case expected of
              SOME m =>
                if m = name then ()
                else diag (library, headerSpan ast,
                           "the file " ^ file ^ " holds the module `" ^ name ^ "`, and it is read for an import of `" ^ m ^ "`")
            | NONE => ()
          val A.Module (_, {imports = explicit, ...}) = ast
          val importsPrelude = List.exists (fn A.Import (_, {module = m, ...}) => nameOf m = "Prelude") explicit
          val all = if name = "Prelude" orelse importsPrelude then explicit else explicit @ [implicitPrelude ()]
          val targets = List.mapPartial (fn i => Option.map (fn t => (i, t)) (target (library, i))) all
          val node = {id = id, name = name, file = file, library = library, ast = ast,
                      imports = List.map (fn (i, (t, _)) => (i, t)) targets}
        in
          nodes := M.insert (!nodes, id, node);
          order := id :: !order;
          List.app
            (fn (A.Import (_, {module = m, ...}), (t, SOME f)) =>
                  visit (t, f, library orelse String.isPrefix (RhcLibrary.name ^ ":") t, SOME (nameOf m))
              | (_, (_, NONE)) => ())
            targets
        end

      val rootIds =
        List.map
          (fn file =>
             let
               val ast = parse (file, false)
               val id = moduleName ast
             in
               if M.member (!nodes, id) then () else add (id, file, false, NONE, ast);
               id
             end)
          roots

      (* Tarjan's algorithm: a group is complete once its root is *)
      val index : int M.map ref = ref M.empty
      val low : int M.map ref = ref M.empty
      val onStack : bool M.map ref = ref M.empty
      val stack : string list ref = ref []
      val counter = ref 0
      val groups : node list list ref = ref []
      fun get (m, k) = valOf (M.find (!m, k))
      fun connect v =
        let
          val () = (index := M.insert (!index, v, !counter); low := M.insert (!low, v, !counter);
                    counter := !counter + 1; stack := v :: !stack; onStack := M.insert (!onStack, v, true))
          val {imports, ...} : node = get (nodes, v)
          fun edge (_, w) =
            if not (M.member (!nodes, w)) then ()
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
              groups := List.map (fn id => get (nodes, id)) inOrder :: !groups
            end
          else ()
        end
      val () = List.app (fn v => if M.member (!index, v) then () else connect v) (List.rev (!order))
    in
      {groups = List.rev (!groups), roots = rootIds, diags = List.rev (!diags)}
    end
end

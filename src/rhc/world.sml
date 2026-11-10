(* rhc's saved world (the haskell98 roadmap's D45, its B until M21's store
   lands): rhc with its library read, its names resolved and its modules
   checked, saved as a VM image as rune-repl.img is (Runtime.save), which
   bin/rhc restores so that a check or a compile reads and checks only the
   program's own modules against it. `make bin/rhc.img` makes it again
   whenever rhc, the VM or a file of share/rhc changes, and bin/rhc
   restores it only where its identity, rhc's own (Config, a digest of
   rhc.plan's closure: the desugaring and Core to Mid among it), is that
   of bin/rhc.rbc, so that a world made by another rhc is never used.

   A program goes the whole way, library and all, as the reference: with
   `--whole`; where there is no saved world; where the options that shape
   the library's reading are not the world's (`--names=greatest`,
   `--cycle-default=scc`); and where the library's files or the directory
   --share names are not those it was saved with. Either way the program
   reaches the same modules of the library, in the same order
   (RhcGraph.canonical), and the same numbers for its own fresh variables
   (RhcNames.programCounters), so that the two print alike: the jobs
   hs/world/* hold them to it. *)
structure RhcWorld =
struct
  structure M = HsStringMap
  structure G = RhcGraph

  (* the library as it was saved: the directory --share named, each file
     of its modules with its bytes, its graph, and what its groups left *)
  type world = {share : string, files : (string * string) list, graph : G.graph, state : RhcNames.state}

  val world : world option ref = ref NONE

  (* --whole: the whole program read and checked, the saved world unused *)
  val whole = ref false

  fun readBytes path =
    let val f = BinIO.openIn path
    in Byte.bytesToString (BinIO.inputAll f) before BinIO.closeIn f end

  (* the library's files of modules as they are now *)
  fun libraryNow () = List.map (fn (_, f) => (f, readBytes f)) (G.libraryFiles ())

  (* `make image` reads and checks the library, keeps it as the world and
     saves the running rhc to `image`, and beside it `image.identity`, rhc's
     own identity (Config, a digest of rhc.plan's closure), which bin/rhc
     holds to bin/rhc.identity before it restores the image: `Saved` in
     this world, `Restored` in one runevm --restore starts *)
  fun make (image : string) : Runtime.world =
    let
      val share = case !RhcLibrary.share of SOME d => d | NONE => raise RhcOptions.Usage "--make-world needs --share DIR"
      val g = G.loadLibrary ()
      val nodes = List.concat (#groups g)
      val s = RhcNames.groups (RhcNames.extend (RhcNames.initial (RhcNames.leavesOf nodes), nodes), #groups g,
                               HsModules.Least, SOME HsInfer.PerModule)
    in
      world := SOME {share = share, files = libraryNow (), graph = g, state = s};
      TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr;
      ignore (Runtime.share ());
      case Runtime.save image of
        Runtime.Saved =>
          let val out = TextIO.openOut (image ^ ".identity")
          in TextIO.output (out, Config.identity ^ "\n"); TextIO.closeOut out; Runtime.Saved end
      | Runtime.Restored => Runtime.Restored
    end

  (* the world, where a program may go from it *)
  fun usable (fixpoint, check) =
    case !world of
      NONE => NONE
    | SOME w =>
        if !whole orelse fixpoint <> HsModules.Least orelse check <> SOME HsInfer.PerModule then NONE
        else if !RhcLibrary.share <> SOME (#share w) then NONE
        else if libraryNow () <> #files w then NONE
        else SOME w

  (* what `--world` says: whether a check goes from the saved world *)
  fun describe () =
    case !world of
      NONE => "rhc: no saved world: every program is read and checked whole"
    | SOME w =>
        "rhc: a saved world of the library in " ^ #share w ^ ", " ^ Int.toString (length (List.concat (#groups (#graph w)))) ^
        " modules, rhc's identity " ^ Config.identity ^
        (case usable (HsModules.Least, SOME HsInfer.PerModule) of
           SOME _ => ""
         | NONE => if !whole then " (unused: --whole)" else " (unused: the library's files or --share differ)")

  (* `program {roots, dotted, fixpoint, check}` is the graph of the program
     of `roots` and what names (and with `check` the checker) found of it,
     from the saved world where it can, else whole (RhcNames.run) *)
  fun program {roots : string list, dotted : bool, fixpoint : HsModules.fixpoint,
               check : HsInfer.cycleDefault option} : G.graph * RhcNames.result =
    case usable (fixpoint, check) of
      NONE =>
        let val g = G.load {roots = roots, dotted = dotted}
        in (g, RhcNames.run (g, fixpoint, check)) end
    | SOME w =>
        let
          val libraryGroups = #groups (#graph w)
          val known = List.foldl (fn (n : G.node, m) => M.insert (m, #id n, n)) M.empty (List.concat libraryGroups)
          val gp = G.loadFrom {roots = roots, dotted = dotted, known = known, library = false}
          val nodes = List.concat (#groups gp)
          val s = RhcNames.groups (RhcNames.extend (#state w, nodes), #groups gp, fixpoint, check)
          (* the modules of the library the program reaches *)
          fun reach (id, seen) =
            if M.member (seen, id) then seen
            else
              case M.find (known, id) of
                SOME (n : G.node) => List.foldl (fn ((_, t), s) => reach (t, s)) (M.insert (seen, id, ())) (#imports n)
              | NONE => seen
          val reached = List.foldl (fn (n : G.node, s) => List.foldl (fn ((_, t), s) => reach (t, s)) s (#imports n))
                          M.empty nodes
          fun keeps (n : G.node) = not (#library n) orelse M.member (reached, #id n)
          val libraryFiles = List.foldl (fn (n : G.node, m) => M.insert (m, #file n, keeps n)) M.empty (List.concat libraryGroups)
          val r = RhcNames.result (s, isSome check)
        in
          ({groups = List.filter (List.all keeps) libraryGroups @ #groups gp, roots = #roots gp, diags = #diags gp},
           {modules = List.filter (keeps o #1) (#modules r), exports = #exports r,
            diags = List.filter (fn d => not (#library d) orelse getOpt (M.find (libraryFiles, #file (#span d)), true)) (#diags r),
            types = #types r, evidence = #evidence r,
            derived = List.filter (fn (h, _, _) => not (M.member (known, h)) orelse M.member (reached, h)) (#derived r)})
        end
end

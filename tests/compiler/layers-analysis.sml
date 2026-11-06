(* The analysis of a build, as the language server's worker runs it, for
   tests/runner's layers check: with RUNE_LAYER_DUMP set the units it binds say
   their hashes (UnitBasis.dumpLayers), to hold against a batch compile's.
   usage: layers-analysis LIB BUILD *)
structure LayersAnalysis =
struct
  structure C = CompilerApi
  structure A = C.Analysis
  fun main (lib, build) =
    let
      val parent = C.session {lib = SOME lib, flags = []}
      (* the workspace above the build, which names its units as a compile's
         (Workspace.find, as the worker's rootFile finds it) *)
      val workspace = C.Workspace.find {file = OS.Path.mkAbsolute {path = build, relativeTo = OS.FileSys.getDir ()}, windows = false}
      val project = C.Project.read (parent, {file = build, workspace = workspace, variables = [], overlays = [], windows = false})
      val texts = List.filter (fn i : C.Project.input => #kind i = "source") (C.Project.inputs project)
      fun textOf file =
        case List.find (fn i : C.Project.input => #file i = file) texts of
          SOME i => #text i
        | NONE => let val input = BinIO.openIn file
                  in Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input end
      val inputs = List.map (fn s : C.Project.source =>
                               {file = #file s, text = textOf (#file s), mode = #mode s, annotations = #annotations s,
                                revision = ""} : A.input) (C.Project.sources project)
      val context = A.create (parent, {context = "layers"})
      val result = A.check (context, {project = SOME project, inputs = inputs, cancelled = fn () => false})
      val diagnostics = A.diagnostics result
      val () = print ("analysis: " ^ Int.toString (length inputs) ^ " inputs, " ^ Int.toString (#checked (A.work result))
                      ^ " units checked, " ^ Int.toString (length diagnostics) ^ " diagnostics\n")
      val () = List.app (fn d : C.diagnostic => print ("diagnostic: " ^ #message d ^ "\n"))
                        (List.take (diagnostics, Int.min (length diagnostics, 20)))
    in
      A.close context; C.close parent
    end
end
val () = case CommandLine.arguments () of
           [lib, build] => LayersAnalysis.main (lib, build)
         | _ => (print "usage: layers-analysis LIB BUILD\n"; OS.Process.exit OS.Process.failure)

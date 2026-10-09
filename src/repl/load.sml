(* rune-repl's loader: the units the file named first lists, loaded one
   after another by Runtime.load and each run as it is loaded -- the Basis
   Library's, the compiler's, the REPL's, whose last runs the REPL
   (docs/repl.md). A unit is found by its name in the list's directory. What
   follows the list is the REPL's. *)
val () =
  case CommandLine.arguments () of
    list :: _ =>
      let
        val ins = TextIO.openIn list
        val names = List.filter (fn s => s <> "") (String.fields (fn c => c = #"\n") (TextIO.inputAll ins))
        val dir = OS.Path.dir list
      in
        TextIO.closeIn ins;
        List.app (fn name => Runtime.load (OS.Path.joinDirFile {dir = dir, file = OS.Path.file name}) ()) names
      end
  | [] => (TextIO.output (TextIO.stdErr, "rune-repl: no list of units\n"); OS.Process.exit OS.Process.failure)

(* rune-repl's loader: the units the file named first lists -- the Basis
   Library's, the compiler's, the REPL's, whose last but the Basis's own
   final ones runs the REPL (docs/repl.md) -- read, every one of them first,
   and then linked one after another by Runtime.link and each run as it is
   linked. A unit is found by its name in the list's directory. Reading them
   all first makes the REPL saved as an image whole: the units after the
   one that saves it are in the image too, and the image runs from any
   directory. What follows the list is the REPL's. *)
val () =
  case CommandLine.arguments () of
    list :: _ =>
      let
        val ins = TextIO.openIn list
        val names = List.filter (fn s => s <> "") (String.fields (fn c => c = #"\n") (TextIO.inputAll ins))
        val dir = OS.Path.dir list
        fun read name =
          let val inp = BinIO.openIn (OS.Path.joinDirFile {dir = dir, file = OS.Path.file name})
          in BinIO.inputAll inp before BinIO.closeIn inp end
        val () = TextIO.closeIn ins
        val units = List.map read names
      in
        List.app (fn bytes => Runtime.link bytes ()) units
      end
  | [] => (TextIO.output (TextIO.stdErr, "rune-repl: no list of units\n"); OS.Process.exit OS.Process.failure)

(* The driver of the mutants of names (tests/runner/hsnames.sml): rhc's
   `--dump-names`, built from rhc's own sources (src/rhc/library.sml,
   graph.sml, names.sml) with a mutant's edit, so that a mutant costs a
   build of these and not of rhc.

     driver --share DIR [--names=least|greatest] [--dotted-names] FILE.hs... *)
structure NamesDriver =
struct
  fun main () =
    let
      (* the options of names, steps of the program's setting, as rhc's *)
      val steps = ref []
      fun step s = steps := !steps @ [s]
      fun go ([], files) = List.rev files
        | go ("--share" :: d :: rest, files) = (RhcLibrary.share := SOME d; go (rest, files))
        | go ("--names=least" :: rest, files) = (step (HsLanguage.Off HsLanguage.GreatestFixpointNames); go (rest, files))
        | go ("--names=greatest" :: rest, files) = (step (HsLanguage.On HsLanguage.GreatestFixpointNames); go (rest, files))
        | go ("--dotted-names" :: rest, files) = (step (HsLanguage.On HsLanguage.HierarchicalModules); go (rest, files))
        | go (f :: rest, files) = go (rest, f :: files)
      val files = go (CommandLine.arguments (), [])
      val g = RhcGraph.load {roots = files, setting = {edition = HsLanguage.Haskell98, steps = !steps}}
    in
      RhcNames.dump (g, RhcNames.run (g, false));
      OS.Process.success
    end
    handle HsSource.Error (_, msg) => (TextIO.output (TextIO.stdErr, msg ^ "\n"); OS.Process.failure)
end

val _ = OS.Process.exit (NamesDriver.main ())

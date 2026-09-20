(* Poly/ML entry point of runedoc: polyc exports `main`. *)
fun main () = OS.Process.exit (DocMain.main (CommandLine.name (), CommandLine.arguments ()))

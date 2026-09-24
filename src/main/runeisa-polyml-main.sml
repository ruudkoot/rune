(* Poly/ML entry point of runeisa: polyc exports `main`. *)
fun main () = OS.Process.exit (IsaMain.main (CommandLine.name (), CommandLine.arguments ()))

(* Poly/ML entry point of runeopt: polyc exports `main`. *)
fun main () = OS.Process.exit (OptMain.main (CommandLine.name (), CommandLine.arguments ()))

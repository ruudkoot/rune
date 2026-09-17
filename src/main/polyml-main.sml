(* Poly/ML entry point: polyc exports `main`. *)
fun main () = OS.Process.exit (Main.main (CommandLine.name (), CommandLine.arguments ()))

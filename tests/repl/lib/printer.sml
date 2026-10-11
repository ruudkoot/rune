(* installs a printer for Printed.t: used twice by printers.in, the second
   time from the cache, where the name of the type is the same *)
val _ = Compiler.addPrettyPrinter (fn _ => fn () => fn (x : Printed.t) => Compiler.PrettyString "<printed>")

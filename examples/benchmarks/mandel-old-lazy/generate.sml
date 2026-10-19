(* Run in a benchmark directory to regenerate its deterministic parameter data.
   Runtime rows preserve the original Main's repeated getArgs dependency. *)
structure MandelProfileInputs =
struct
  val _ = if (OS.FileSys.isDir "data" handle OS.SysErr _ => false) then () else OS.FileSys.mkDir "data"
  fun write (name, repeats, width, height) =
    let val output = TextIO.openOut ("data/" ^ name ^ ".params")
        val row = String.concat ["~2.0 ~2.0 2.0 2.0 ", Int.toString width, " ", Int.toString height, " 75\n"]
        val _ = TextIO.output (output, Int.toString repeats ^ "\n")
        fun loop 0 = () | loop n = (TextIO.output (output, row); loop (n - 1))
        val _ = loop repeats
    in TextIO.closeOut output end
  val _ = List.app write [("smoke", 1, 7, 5), ("normal", 100, 25, 25), ("large", 100, 180, 180)]
end

(* Runtime size rows replace the original noinline identity salt using SML97
   input; coordinate scaling remains the original constant 200. *)
structure MandelTwoProfileInputs =
struct
  val _ = if (OS.FileSys.isDir "data" handle OS.SysErr _ => false) then () else OS.FileSys.mkDir "data"
  fun write (name, repeats, extent) =
    let val output = TextIO.openOut ("data/" ^ name ^ ".sizes")
        val _ = TextIO.output (output, Int.toString repeats ^ "\n")
        fun loop 0 = () | loop n = (TextIO.output (output, Int.toString extent ^ "\n"); loop (n - 1))
        val _ = loop repeats
    in TextIO.closeOut output end
  val _ = List.app write [("smoke", 1, 64), ("normal", 2, 200), ("large", 20, 200)]
end

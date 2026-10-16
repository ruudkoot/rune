structure GenerateCichelliInput =
struct
  fun write (profile,n) =
    let val out = TextIO.openOut ("data/" ^ profile ^ ".indices")
        fun loop i = if i>n then () else (TextIO.output (out,Int.toString i ^ "\n"); loop (i+1))
        val _ = TextIO.output (out,Int.toString n ^ "\n")
        val _ = loop 1
        val _ = TextIO.closeOut out
    in () end
  val _ = List.app write [("smoke",6),("normal",60),("large",300)]
end

functor BenchElizaDriverFn (K : sig
  type text
  val conversation : string list -> int -> text
  val length : text -> int
end) =
struct
  fun readLines path =
    let val input = TextIO.openIn path
        fun loop () = case TextIO.inputLine input of NONE => [] | SOME line =>
          (if String.size line > 0 andalso String.sub (line, String.size line - 1) = #"\n"
           then String.substring (line, 0, String.size line - 1) else line) :: loop ()
        val result = loop () handle ex => (TextIO.closeIn input; raise ex)
        val _ = TextIO.closeIn input
    in result end
  fun run [argument, path] =
    let val n = BenchInput.between (1, 65000) (BenchInput.integer argument)
        val lines = readLines path
        val total = ref (IntInf.fromInt 0)
        fun loop i = if i > n then () else
          let val prefix = i mod 20
              val length = K.length (K.conversation lines prefix)
              val expected = Vector.sub (BenchElizaLengths.values, prefix)
              val _ = if length = expected then ()
                      else raise Fail "incorrect result: Eliza response length differs"
          in total := IntInf.+ (!total, IntInf.fromInt length); loop (i + 1) end
        val _ = loop 1
    in Int.toString n ^ ":" ^ IntInf.toString (!total) ^ ":checked" end
    | run _ = raise Fail "Eliza expects iteration count and fixed conversation input"
end

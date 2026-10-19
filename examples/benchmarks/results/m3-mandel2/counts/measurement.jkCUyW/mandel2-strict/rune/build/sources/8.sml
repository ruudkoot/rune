functor BenchMandelTwoDriverFn (K : sig
  type tree
  val build : int * int -> int * int -> tree
  val write : int -> (string -> unit) -> tree -> int
end) =
struct
  val _ = if Real.radix = 2 andalso Real.precision = 53 then ()
          else raise Fail "benchmark requires binary64 Real"
  structure Check = MandelTreeCheckFn (K)
  fun line input = case TextIO.inputLine input of SOME s => s | NONE => raise Fail "short Mandel2 size file"
  fun integer text = case String.tokens Char.isSpace text of
      [value] => BenchInput.integer value | _ => raise Fail "invalid Mandel2 parameter row"
  fun run [sizes, reference] =
    let val input = TextIO.openIn sizes
        fun main () =
          let val repeats = BenchInput.between (1, 100) (integer (line input))
              val nodes = ref 0
              fun loop 0 = ()
                | loop n =
                    let val width = BenchInput.between (1, 200) (integer (line input))
                        val count = Check.run width reference
                    in nodes := !nodes + count; loop (n - 1) end
              val _ = loop repeats
              val _ = case TextIO.inputLine input of NONE => () | SOME _ => raise Fail "extra Mandel2 size row"
          in Int.toString repeats ^ ":" ^ Int.toString (!nodes) ^ ":checked" end
        val result = main () handle ex => (TextIO.closeIn input; raise ex)
        val _ = TextIO.closeIn input
    in result end
    | run _ = raise Fail "Mandel2 expects deterministic size file and complete tree reference"
end

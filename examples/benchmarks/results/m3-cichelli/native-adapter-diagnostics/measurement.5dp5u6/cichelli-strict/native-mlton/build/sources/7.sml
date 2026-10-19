functor BenchCichelliDriverFn (K : sig
  type feedback
  val cichelli : int -> feedback
  val emitFeedback : (string -> unit) -> feedback -> unit
end) =
struct
  fun run [path,reference] =
    let val input = TextIO.openIn path
        val expected = BinIO.openIn reference handle ex => (TextIO.closeIn input; raise ex)
        val bytes = ref 0
        fun emit text =
          let fun loop i = if i=String.size text then () else
                (case BinIO.input1 expected of NONE => raise Fail "incorrect result: extra Cichelli output"
                 | SOME value => if Word8.toInt value=Char.ord (String.sub (text,i))
                   then (bytes := !bytes+1; loop (i+1))
                   else raise Fail "incorrect result: Cichelli byte differs")
          in loop 0 end
        fun integer () = case TextIO.inputLine input of NONE => raise Fail "missing Cichelli parameter"
          | SOME text => (case String.tokens Char.isSpace text of [word] => BenchInput.integer word
              | _ => raise Fail "invalid Cichelli parameter row")
        fun work () =
          let val n = BenchInput.between (0,300) (integer ())
              fun loop 0 = ()
                | loop left =
                  let val index = BenchInput.between (1,300) (integer ())
                      val _ = K.emitFeedback emit (K.cichelli index)
                  in loop (left-1) end
              val _ = loop n
              val _ = case TextIO.inputLine input of NONE => () | SOME _ => raise Fail "extra Cichelli parameters"
              val _ = if Option.isSome (BinIO.input1 expected) then raise Fail "incorrect result: short Cichelli output" else ()
          in Int.toString n ^ ":" ^ Int.toString (!bytes) ^ ":checked" end
        val result = work () handle ex => (TextIO.closeIn input; BinIO.closeIn expected; raise ex)
        val _ = TextIO.closeIn input
        val _ = BinIO.closeIn expected
    in result end
    | run _ = raise Fail "Cichelli expects runtime indices and complete output reference"
end

functor BenchInferDriverFn (K : sig
  type text
  val render : string -> text
  val app : (char -> unit) -> text -> unit
end) =
struct
  fun read path =
    let val input = TextIO.openIn path
        val text = TextIO.inputAll input handle ex => (TextIO.closeIn input; raise ex)
        val _ = TextIO.closeIn input
    in text end
  fun check source reference expectedHash =
    let val input = BinIO.openIn reference
        val hash = ref (0w0 : Word64.word)
        val count = ref 0
        fun emit c =
          let val _ = case BinIO.input1 input of
                    NONE => raise Fail "incorrect result: extra inference output"
                  | SOME byte => if Word8.toInt byte = Char.ord c then ()
                      else raise Fail "incorrect result: inference output byte differs"
          in hash := Word64.+ (Word64.fromInt (Char.ord c), Word64.* (!hash,0w31));
             count := !count + 1
          end
        val _ = K.app emit (K.render (read source))
                handle ex => (BinIO.closeIn input; raise ex)
        val extra = BinIO.input1 input
        val _ = BinIO.closeIn input
    in if Option.isSome extra then raise Fail "incorrect result: short inference output"
       else if !hash <> expectedHash then raise Fail "incorrect result: inference hash differs"
       else !count
    end
  fun run [argument,source,reference,hashArgument] =
    let val n = BenchInput.between (1,200) (BenchInput.integer argument)
        val large = case IntInf.fromString hashArgument of SOME value => value
          | NONE => raise Fail "invalid inference hash argument"
        val _ = if IntInf.>= (large,0) andalso IntInf.< (large,18446744073709551616) then ()
                else raise Fail "inference hash is outside64-bit unsigned range"
        val expectedHash = Word64.fromLargeInt large
        fun loop 0 total = total
          | loop left total = loop (left-1) (IntInf.+ (total,IntInf.fromInt (check source reference expectedHash)))
        val total = loop n 0
    in Int.toString n ^ ":" ^ IntInf.toString total ^ ":checked" end
    | run _ = raise Fail "infer expects repetitions, source input, full reference and expected hash"
end

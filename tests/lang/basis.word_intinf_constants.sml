structure WordIntInfConstants =
struct
  val modulus = IntInf.pow(IntInf.fromInt 2,Word.wordSize)
  val all = Word.notb 0w0
  val () = print(Bool.toString(Word.toLargeInt all = IntInf.-(modulus,IntInf.fromInt 1)) ^ "\n")
  val () = print(Bool.toString(Word.toLargeIntX all = IntInf.fromInt (~1)) ^ "\n")
  val () = print(Bool.toString(Word.fromLargeInt modulus = 0w0 andalso Word.fromLargeInt(IntInf.fromInt (~1))=all) ^ "\n")
end

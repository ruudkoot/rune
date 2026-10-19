functor BenchAtomDriverFn (K : sig val run : int -> Word32.word vector -> string end) =
struct
  fun run [size,reference] =
    let val count=BenchInput.between(0,4000)(BenchInput.integer size)
        val file=TextIO.openIn reference val data=TextIO.inputAll file val _=TextIO.closeIn file
        fun parse text=if String.size text=8 andalso CharVector.all Char.isHexDigit text
          then(case Word32.fromString text of SOME bits=>bits|NONE=>raise Fail "invalid atom bit fixture")
          else raise Fail "invalid atom bit fixture"
        val expected=Vector.fromList(List.map parse(String.tokens Char.isSpace data))
    in K.run count expected end
    |run _=raise Fail "atom expects prefix length and reviewed binary32 positions"
end

functor BenchHartelGenFftDriverFn (K : sig
  val check : int -> string -> int * int
end) =
struct
  fun run [size,repetitions,reference] =
    let val maximum=BenchInput.between(0,8)(BenchInput.integer size)
        val repeats=BenchInput.between(1,300)(BenchInput.integer repetitions)
        val input=TextIO.openIn reference val expected=TextIO.inputAll input
        val _=TextIO.closeIn input
        val expectedCode=CharVector.foldl(fn(c,sum)=>sum+Char.ord c)0 expected+String.size expected
        val expectedSize=String.size expected
        fun format(code,size)=Int.toString code^"/"^Int.toString size
        val wanted=format(expectedCode,expectedSize)
        fun loop(0,bytes)=Int.toString repeats^":"^wanted^":"^Int.toString bytes
          |loop(left,bytes)=
            let val result=K.check maximum expected
                val _=if result=(expectedCode,expectedSize)then()
                  else raise Fail "incorrect result: generator checksum differs"
                val written=format result
            in loop(left-1,bytes+String.size written+1)end
    in loop(repeats,0)end
    |run _=raise Fail "FFT generator expects maximum exponent, repetitions and reviewed source text"
end

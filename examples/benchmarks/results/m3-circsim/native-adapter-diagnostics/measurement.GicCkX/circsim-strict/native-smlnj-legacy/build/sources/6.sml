functor BenchCircsimDriverFn (K : sig
  val runChecked : bool -> int -> int -> string -> int * int
end) =
struct
  fun run heads [bits,cycles,repetitions,reference] =
    let val bits=BenchInput.between(1,16)(BenchInput.integer bits)
        val cycles=BenchInput.between(0,200)(BenchInput.integer cycles)
        val repeats=BenchInput.between(1,97)(BenchInput.integer repetitions)
        val input=TextIO.openIn reference val expected=TextIO.inputAll input val _=TextIO.closeIn input
        val expectedChars=String.size expected+(if heads then 1 else 0)
        val expectedCode=if heads then CharVector.foldl(fn(c,sum)=>sum+Char.ord c)0 expected+10+expectedChars else 0
        fun loop(0,bytes)=Int.toString repeats^":"^Int.toString expectedChars^":"^Int.toString expectedCode^":"^Int.toString bytes
          |loop(left,bytes)=
             let val result=K.runChecked heads bits cycles expected
                 val _=if result=(expectedChars,expectedCode)then()else raise Fail "incorrect result: circuit consumer differs"
             in loop(left-1,bytes+(if heads then #1 result else 0))end
    in loop(repeats,0)end
    |run _ _=raise Fail "circuit simulator expects register width, cycles, repetitions and reviewed trace"
end

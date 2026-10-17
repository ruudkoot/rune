functor BenchMinimaxDriverFn (K : sig val prog : string -> string end) =
struct
  fun read path = let val input=TextIO.openIn path val result=TextIO.inputAll input
    val _=TextIO.closeIn input in result end
  fun run [argument,path] =
    let val repeats=BenchInput.between (0,10000) (BenchInput.integer argument)
        val expected=read path
        fun loop (0,total)=Int.toString repeats^":"^Int.toString total
          | loop (n,total)=let val result=K.prog argument
              val _=if result=expected then () else raise Fail "incorrect result: minimax game differs"
            in loop(n-1,total+String.size result)end
    in loop(repeats,0)end
    | run _ = raise Fail "minimax expects repetitions and a complete game fixture"
end

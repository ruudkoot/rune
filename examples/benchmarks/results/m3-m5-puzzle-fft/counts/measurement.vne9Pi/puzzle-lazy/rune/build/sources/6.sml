functor BenchPuzzleDriverFn(K : sig val checked : string -> int end) =
struct
  fun run [count,path] =
    let val n=BenchInput.between(0,80)(BenchInput.integer count)
        val input=TextIO.openIn path val expected=TextIO.inputAll input
        val _=TextIO.closeIn input
        fun loop 0 total=Int.toString n^":"^Int.toString total
          | loop i total=loop(i-1)(total+K.checked expected)
    in loop n 0 end
    | run _=raise Fail "puzzle expects repetitions and minimum fixture"
end

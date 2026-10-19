functor BenchClausifyDriverFn(K : sig val checked : string -> int -> int end) =
struct
  fun run [size,path] =
    let
      val n = BenchInput.between(0,35)(BenchInput.integer size)
      val input = TextIO.openIn path
      val one = TextIO.inputAll input
      val _ = TextIO.closeIn input
      val expected = String.concat(List.tabulate(n,fn _ => one))
      fun loop 0 total = "67:" ^ Int.toString n ^ ":" ^ Int.toString total
        | loop i total = loop(i-1)(total + K.checked expected n)
    in loop 67 0 end
    | run _ = raise Fail "clausify expects copies and clause fixture"
end

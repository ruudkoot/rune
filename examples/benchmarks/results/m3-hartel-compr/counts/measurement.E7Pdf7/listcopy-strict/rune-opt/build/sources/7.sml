functor BenchHartelComprDriverFn (K : sig
  val outputLength : bool -> int -> int
end) =
struct
  fun run copying[argument]=
    let val n=BenchInput.between(0,100000)(BenchInput.integer argument)
        val observed=K.outputLength copying n
        val _=if observed=626*n then()else raise Fail "incorrect result: transformed program length differs"
    in Int.toString observed end
    |run _ _=raise Fail "comprehension compiler expects source repetition count"
end

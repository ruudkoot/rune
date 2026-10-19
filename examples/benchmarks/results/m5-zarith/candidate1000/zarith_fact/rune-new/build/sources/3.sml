structure Benchmark =
struct
  val name="zarith_fact"
  fun run [size,repetitions,reference] =
    let val n=BenchInput.between(0,40)(BenchInput.integer size)
        val count=BenchInput.between(0,1000000)(BenchInput.integer repetitions)
        val expected=case IntInf.fromString reference of SOME v=>v | NONE=>raise Fail "invalid factorial reference"
        fun check value=if value=expected then () else raise Fail "factorial differs"
    in IntInf.toString(BenchZarithRepeat.run count BenchZarithFact.fact n check) end
    | run _=raise Fail "zarith_fact expects n count reference"
end

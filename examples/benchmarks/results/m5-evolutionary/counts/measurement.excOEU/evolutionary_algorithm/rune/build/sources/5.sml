structure Benchmark =
struct
  val name="evolutionary_algorithm"
  fun run [length,population,budget,path]=
    let val n=BenchInput.between(1,1000)(BenchInput.integer length)
        val lambda=BenchInput.between(1,1000)(BenchInput.integer population)
        val evaluations=BenchInput.between(0,100000)(BenchInput.integer budget)
        val _=EvolutionCheck.run n lambda evaluations path
    in Int.toString n^":"^Int.toString lambda^":"^Int.toString evaluations^":checked"end
    | run _=raise Fail "evolution expects chromosome-length population-size budget reference"
end

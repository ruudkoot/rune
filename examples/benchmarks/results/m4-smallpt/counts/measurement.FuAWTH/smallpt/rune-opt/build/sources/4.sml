structure Benchmark =
struct
  val name="smallpt"
  fun run [width,height,samples,path]=
    let val w=BenchInput.between(1,512)(BenchInput.integer width)
        val h=BenchInput.between(1,384)(BenchInput.integer height)
        val n=BenchInput.between(0,6)(BenchInput.integer samples)
        val _=SmallptCheck.run w h n path
    in Int.toString w^":"^Int.toString h^":"^Int.toString n^":checked"end
    | run _=raise Fail "smallpt expects width height samples complete-RGB-reference"
end

structure Benchmark =
struct
  val name="naive-multilayer"
  structure K=BenchMultilayer
  structure F=BenchMultilayerFiles
  val inputs=BenchLazy.delay(fn()=>F.data "data/samples.txt")
  fun run [iterations,path]=
    let val epochs=BenchInput.between(0,1000)(BenchInput.integer iterations)
        val samples=BenchLazy.force inputs
        val random=BenchOCamlRandom.default()
        fun draw()=BenchOCamlRandom.real random 2.0-1.0
        val network=K.fit epochs samples draw
        val expected=F.reference path
        val _=F.check expected network samples
    in Int.toString epochs^":"^Int.toString(Array.length samples)^":checked"end
    | run _=raise Fail "multilayer expects epochs and network reference"
end

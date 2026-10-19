structure Benchmark =
struct
  val name="levinson-durbin"
  structure F=BenchLevinsonFiles
  val inputs=BenchLazy.delay(fn()=>List.map(fn label=>F.data("data/"^label^".pcm"))F.labels)
  fun run [order,path]=
    let val n=BenchInput.between(0,10000)(BenchInput.integer order)
        val data=BenchLazy.force inputs val reference=F.references path
        val _=F.validate n data reference
    in Int.toString n^":"^Int.toString(5*(n+1))^":checked"end
    | run _=raise Fail "Levinson expects order and reference"
end

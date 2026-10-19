structure Benchmark =
struct
  val name="mutstore2"
  type store = int list array
  fun makeStore() : store = Array.array(10,[])
  fun add(store:store,k,e)=Array.update(store,k,e::Array.sub(store,k))
  fun buckets(store:store)=Array.foldr(fn(xs,rest)=>xs::rest)[]store
  fun run args=BenchMutStore.run makeStore add buckets args
end

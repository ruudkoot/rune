structure Benchmark =
struct
  val name="mutstore1"
  type store = int list ref vector
  fun makeStore() : store = Vector.tabulate(10,fn _=>ref[])
  fun add(store:store,k,e)=let val bucket=Vector.sub(store,k)in bucket:=e::(!bucket)end
  fun buckets(store:store)=Vector.foldr(fn(cell,rest)=>(!cell)::rest)[]store
  fun run args=BenchMutStore.run makeStore add buckets args
end

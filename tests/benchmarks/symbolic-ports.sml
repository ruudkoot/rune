structure BenchSymbolicPortTests =
struct
  exception Untouched
  val headCalls=ref 0
  val unknown : ParaffinBenchmark.radical BenchLazy.delay =
    BenchLazy.delay(fn()=>(headCalls := !headCalls+1;raise Untouched))
  val input=BenchStream.cons(unknown,BenchStream.empty())
  val produced=ParaffinBenchmark.mapCells(fn r=>ParaffinBenchmark.C(r,r,r))input
  val _=T.check("paraffins/count-does-not-force-values",fn()=>
    ParaffinBenchmark.length produced=1 andalso !headCalls=0)
  val _=T.check("paraffins/constructor-fields-remain-lazy",fn()=>
    (case BenchStream.head produced of ParaffinBenchmark.C _=>true|_=>false)andalso !headCalls=0)
  val pieces=BenchRegex.parse "[a-b]<09-10>"
  val expansions=Benchmark.expand pieces
  fun string xs=String.implode(BenchStream.foldl(fn(c,chars)=>chars@[c])[]xs)
  val actual=List.map string(BenchStream.take 4 expansions)
  val _=T.check("regexp/order-and-padding",fn()=>actual=["a09","a10","b09","b10"])
  val _=T.check("regexp/descending-letters",fn()=>BenchRegex.values(BenchRegex.Alphabet(#"d",#"a"))=[[#"d"],[#"c"],[#"b"],[#"a"]])
  val _=T.check("regexp/descending-numbers",fn()=>List.map String.implode(BenchRegex.values(BenchRegex.Numeric(10,9,2)))=["10","09"])
  val _=T.check("regexp/invalid-number-rejected",fn()=>(BenchRegex.parse "<1-x>";false)handle Fail _=>true)
end

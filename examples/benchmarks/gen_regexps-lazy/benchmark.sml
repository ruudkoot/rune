structure Benchmark =
struct
  val name="gen_regexps-lazy"
  fun expand [] = BenchStream.singleton(BenchStream.empty())
    |expand(p::rest)=BenchStream.concatMap(fn prefix=>
        BenchStream.map(fn suffix=>BenchStream.append(BenchStream.fromList prefix)suffix)(expand rest))
        (BenchStream.fromList(BenchRegex.values p))
  fun calculate pieces =
    let val chars=BenchStream.concatMap(fn string=>string)(expand pieces)
    in BenchStream.foldl(fn(c,(hash,n))=>(BenchRegex.addChar(c,hash),n+1))(0w0,0)chars end
  fun run args=BenchRegex.run calculate args
end

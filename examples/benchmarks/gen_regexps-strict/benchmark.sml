structure Benchmark =
struct
  val name="gen_regexps-strict"
  fun expand []=[[]]
    |expand(p::rest)=List.concat(List.map(fn prefix=>List.map(fn suffix=>prefix@suffix)(expand rest))(BenchRegex.values p))
  fun calculate pieces=List.foldl(fn(c,(hash,n))=>(BenchRegex.addChar(c,hash),n+1))(0w0,0)(List.concat(expand pieces))
  fun run args=BenchRegex.run calculate args
end

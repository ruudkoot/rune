structure BenchCoverageTests =
struct
  val entries=BenchCatalog.load "examples/benchmarks/manifest.tsv"
  val sources=BenchCoverage.sources "examples/benchmarks/inventory.tsv"
  val _=T.check("benchmark.coverage/complete",fn()=>(BenchCoverage.validate sources entries;true))
  fun rejected expected f=(f();false)handle Fail message=>String.isSubstring expected message
  val first=hd entries
  val _=T.check("benchmark.coverage/missing-import",fn()=>
      rejected "unimplemented import"(fn()=>BenchCoverage.validate sources
        (List.filter(fn(row:BenchCatalog.entry)=> #upstream row<> #upstream first orelse #sourcePath row<> #sourcePath first)entries)))
  fun deferred(row:BenchCoverage.source):BenchCoverage.source=
    if #upstream row= #upstream first andalso #path row= #sourcePath first then
      {upstream= #upstream row,path= #path row,disposition="defer",identity= #identity row,reason="planted missing facility"}
    else row
  val _=T.check("benchmark.coverage/deferred-cannot-run",fn()=>
      rejected "non-import source"(fn()=>BenchCoverage.validate(List.map deferred sources)entries))
  val _=T.check("benchmark.coverage/duplicate-source",fn()=>
      rejected "duplicate coverage source"(fn()=>BenchCoverage.validate(hd sources::sources)entries))
  val _=T.check("benchmark.coverage/documentation",fn()=>(BenchCoverage.documentation entries;true))
  val _=T.check("benchmark.coverage/companions-accounted",fn()=>
      BenchCoverage.companions "examples/benchmarks/source-variants.tsv">0)
end

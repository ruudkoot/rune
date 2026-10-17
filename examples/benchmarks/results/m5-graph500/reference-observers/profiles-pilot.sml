val base="tests/out/benchmarks/graph500-originals/"
val _=List.app(fn(name,scale,ef)=>
 let val edges=BenchGraph500.generate(BenchOCamlRandom.default())scale ef
     val(size,hash)=BenchGraphMarshal.write(base^name^"-ported.marshal")edges
 in print(name^" "^Int.toString size^" "^Word64.toString hash^"\n")end)
 [("normal",12,16),("large",14,16)]
val _=List.app(fn(name,scale,ef)=>
 let val rows=BenchKroneckerPrototype.generate(BenchOCamlRandom.default())scale ef
     val(size,hash)=BenchKroneckerPrototype.write(base^name^"-ported.csv")rows
 in print(name^" "^Int.toString size^" "^Word64.toString hash^"\n")end)
 [("normal",8,4),("large",10,4)]

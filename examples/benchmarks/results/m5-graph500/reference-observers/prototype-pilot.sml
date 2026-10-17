val rows=BenchKroneckerPrototype.generate(BenchOCamlRandom.default())3 1
val(size,hash)=BenchKroneckerPrototype.write"tests/out/benchmarks/graph500-originals/smoke-ported.csv"rows
val _=print(Int.toString size^" "^Word64.toString hash^"\n")

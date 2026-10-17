val edges=BenchGraph500.generate(BenchOCamlRandom.default())6 4
val base="tests/out/benchmarks/graph500-originals/"
val(size,hash)=BenchGraphMarshal.write(base^"smoke-ported.marshal")edges
val _=print(Int.toString size^" "^Word64.toString hash^"\n")
val decoded=BenchGraphMarshal.read(base^"smoke.marshal")
val _=Array.appi(fn(i,(a,b,w))=>let val(x,y,z)=Array.sub(decoded,i)
 in if a=x andalso b=y andalso Real.==(w,z)then()else raise Fail "graph edge mismatch"end)edges
val _=print"all 256 decoded edges match generated values\n"

structure A=BenchBSPTProgramFn(BenchNeed)
structure B=BenchBSPTProgramFn(BenchStrict)
fun emit path values=
 let val out=TextIO.openOut path
     val count=BenchStream.foldl(fn(c,n)=>(TextIO.output1(out,c);n+1))0 values
     val _=TextIO.closeOut out
 in print(path^" "^Int.toString count^"\n")end
val _=emit"tests/out/benchmarks/bspt-originals/lazy.render"(A.prog"batch\n")
val _=emit"tests/out/benchmarks/bspt-originals/strict.render"(B.prog"batch\n")

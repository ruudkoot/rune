functor Driver(D:BENCH_SUSPEND)=struct
 structure K=BenchReptileFn(D)
 structure Check=BenchReptileCheckFn(K)
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/reptile/reptile.faststdin","919E8F689ED9FB45"]="500"then print"PASS original 500-repetition smoke\n"else raise Fail"repetition count"
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/reptile/reptile.stdin","5113F639C24EF047"]="500"then print"PASS original 500-repetition normal\n"else raise Fail"repetition count"
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/reptile/reptile.slowstdin","F2391102B5A435AD"]="500"then print"PASS original 500-repetition large\n"else raise Fail"repetition count"
end
structure A=Driver(BenchNeed)
structure B=Driver(BenchStrict)

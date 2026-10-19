structure K=BenchReptileFn(BenchNeed)
structure Check=BenchReptileCheckFn(K)
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/reptile/reptile.faststdin","919E8F689ED9FB45"]="500"then print"PASS original 500-repetition Reptile smoke loop\n"
 else raise Fail"source Reptile loop"

structure K=BenchTransformFn(BenchNeed)
structure Check=BenchTransformCheckFn(K)
val _=T.check("transform/mlkit-smoke",fn()=>Check.run["8"]="28275")
